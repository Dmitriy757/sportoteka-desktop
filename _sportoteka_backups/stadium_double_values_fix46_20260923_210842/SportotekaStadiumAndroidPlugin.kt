package by.sportoteka.stadium_android

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.Choreographer
import android.view.SurfaceView
import android.view.TextureView
import android.view.View as AndroidView
import android.widget.FrameLayout
import com.google.android.filament.Camera
import com.google.android.filament.Engine
import com.google.android.filament.View
import com.google.android.filament.utils.ModelViewer
import com.google.android.filament.utils.Utils
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.util.concurrent.Executors

class SportotekaStadiumAndroidPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Filament's Android utilities load the core / gltfio native libraries.
        // Keeping this renderer native avoids Flutter TextureRegistry / Impeller
        // swapchain issues that can produce a blank Thermion view on tablets.
        // Utils.init() loads Filament, glTF I/O utilities and the required JNI layer.
        Utils.init()
        binding.platformViewRegistry.registerViewFactory(
            "sportoteka/native_stadium",
            StadiumViewFactory(
                binding.binaryMessenger,
                binding.flutterAssets,
            ),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
}

private class StadiumViewFactory(
    private val messenger: BinaryMessenger,
    private val flutterAssets: FlutterPlugin.FlutterAssets,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?> ?: emptyMap()
        return StadiumPlatformView(context, viewId, messenger, flutterAssets, params)
    }
}

private class StadiumPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    private val flutterAssets: FlutterPlugin.FlutterAssets,
    params: Map<String, Any?>,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val root = FrameLayout(context)
    private val useTextureView = params["useTextureView"] as? Boolean ?: true
    private val renderHost: AndroidView = if (useTextureView) {
        TextureView(context)
    } else {
        SurfaceView(context)
    }
    private val channel = MethodChannel(messenger, "sportoteka/native_stadium/$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val choreographer = Choreographer.getInstance()

    private var disposed = false
    private var readySent = false
    private var assetLoaded = false
    private var loadGeneration = 0

    private val engine: Engine = Engine.create(Engine.Backend.OPENGL)
    private val modelViewer: ModelViewer

    private var eyeX = number(params, "eyeX", 0.0)
    private var eyeY = number(params, "eyeY", 10.0)
    private var eyeZ = number(params, "eyeZ", 10.0)
    private var targetX = number(params, "targetX", 0.0)
    private var targetY = number(params, "targetY", 0.0)
    private var targetZ = number(params, "targetZ", 0.0)
    private var fov = number(params, "verticalFovDegrees", 55.0)
    private var nearPlane = number(params, "nearPlane", 0.05)
    private var farPlane = number(params, "farPlane", 5000.0)

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (disposed) return
            choreographer.postFrameCallback(this)
            try {
                val rendered = modelViewer.render(frameTimeNanos)
                if (rendered) {
                    // Flutter Platform Views require explicit invalidation for
                    // SurfaceView / SurfaceTexture-backed content after a frame.
                    renderHost.invalidate()
                    root.invalidate()
                }
                if (rendered && assetLoaded && !readySent) {
                    readySent = true
                    channel.invokeMethod("ready", null)
                }
            } catch (t: Throwable) {
                reportError("Render: ${t.message ?: t.javaClass.simpleName}")
            }
        }
    }

    init {
        val backgroundArgb = (params["backgroundColor"] as? Number)?.toInt()
            ?: Color.rgb(38, 70, 58)
        root.setBackgroundColor(backgroundArgb)
        renderHost.setBackgroundColor(backgroundArgb)
        renderHost.isClickable = false
        renderHost.isFocusable = false
        if (renderHost is SurfaceView) {
            renderHost.holder.setFormat(PixelFormat.OPAQUE)
            renderHost.setZOrderOnTop(false)
            renderHost.setZOrderMediaOverlay(false)
        }
        root.addView(
            renderHost,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        modelViewer = if (renderHost is TextureView) {
            ModelViewer(
                textureView = renderHost,
                engine = engine,
                manipulator = null,
            )
        } else {
            ModelViewer(
                surfaceView = renderHost as SurfaceView,
                engine = engine,
                manipulator = null,
            )
        }

        modelViewer.renderer.clearOptions = modelViewer.renderer.clearOptions.apply {
            clear = true
            clearColor = doubleArrayOf(0.149f, 0.275f, 0.227f, 1.0f)
        }

        // Tablet-safe defaults. The tactical overlay is projected by Flutter,
        // so dynamic resolution is intentionally disabled for pixel stability.
        modelViewer.view.renderQuality = modelViewer.view.renderQuality.apply {
            hdrColorBuffer = View.QualityLevel.MEDIUM
        }
        modelViewer.view.dynamicResolutionOptions =
            modelViewer.view.dynamicResolutionOptions.apply { enabled = false }
        modelViewer.view.antiAliasing = View.AntiAliasing.FXAA

        channel.setMethodCallHandler(this)
        renderHost.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            applyCamera()
        }
        choreographer.postFrameCallback(frameCallback)
        // Dart calls loadAsset after its MethodChannel handler is attached.
    }

    override fun getView() = root

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setCamera" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                eyeX = number(args, "eyeX", eyeX)
                eyeY = number(args, "eyeY", eyeY)
                eyeZ = number(args, "eyeZ", eyeZ)
                targetX = number(args, "targetX", targetX)
                targetY = number(args, "targetY", targetY)
                targetZ = number(args, "targetZ", targetZ)
                fov = number(args, "verticalFovDegrees", fov)
                nearPlane = number(args, "nearPlane", nearPlane)
                farPlane = number(args, "farPlane", farPlane)
                applyCamera()
                result.success(null)
            }
            "loadAsset" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                val path = args["assetPath"] as? String
                if (path.isNullOrBlank()) {
                    result.error("BAD_ASSET", "assetPath is empty", null)
                } else {
                    loadAsset(path)
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun loadAsset(assetPath: String) {
        val generation = ++loadGeneration
        readySent = false
        assetLoaded = false
        ioExecutor.execute {
            try {
                val buffer = readFlutterAsset(assetPath)
                mainHandler.post {
                    if (disposed || generation != loadGeneration) return@post
                    try {
                        modelViewer.loadModelGlb(buffer)
                        assetLoaded = true
                        applyCamera()
                    } catch (t: Throwable) {
                        reportError("GLB: ${t.message ?: t.javaClass.simpleName}")
                    }
                }
            } catch (t: Throwable) {
                mainHandler.post {
                    if (!disposed && generation == loadGeneration) {
                        reportError("Asset $assetPath: ${t.message ?: t.javaClass.simpleName}")
                    }
                }
            }
        }
    }

    private fun applyCamera() {
        if (disposed) return
        val width = renderHost.width
        val height = renderHost.height
        if (width <= 1 || height <= 1) return
        try {
            val aspect = width.toDouble() / height.toDouble()
            val safeNear = nearPlane.coerceAtLeast(0.001)
            val safeFar = farPlane.coerceAtLeast(safeNear + 1.0)
            modelViewer.camera.lookAt(
                eyeX, eyeY, eyeZ,
                targetX, targetY, targetZ,
                0.0, 1.0, 0.0,
            )
            modelViewer.camera.setProjection(
                fov.coerceIn(10.0, 120.0),
                aspect,
                safeNear,
                safeFar,
                Camera.Fov.VERTICAL,
            )
        } catch (t: Throwable) {
            reportError("Camera: ${t.message ?: t.javaClass.simpleName}")
        }
    }

    private fun readFlutterAsset(assetPath: String): ByteBuffer {
        val flutterAssetKey = flutterAssets.getAssetFilePathByName(assetPath)

        // When the host keeps .glb uncompressed, memory-map it directly. This
        // avoids holding both a 50 MB byte[] and a second direct ByteBuffer on
        // tablets. Fall back to a streamed copy for compressed APK assets.
        try {
            root.context.assets.openFd(flutterAssetKey).use { afd ->
                FileInputStream(afd.fileDescriptor).use { input ->
                    return input.channel.map(
                        FileChannel.MapMode.READ_ONLY,
                        afd.startOffset,
                        afd.length,
                    )
                }
            }
        } catch (_: Throwable) {
            val bytes = root.context.assets.open(flutterAssetKey).use { it.readBytes() }
            return ByteBuffer.allocateDirect(bytes.size).apply {
                put(bytes)
                flip()
            }
        }
    }

    private fun reportError(message: String) {
        if (disposed) return
        channel.invokeMethod("error", message)
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
        loadGeneration += 1
        choreographer.removeFrameCallback(frameCallback)
        channel.setMethodCallHandler(null)
        ioExecutor.shutdownNow()
        // ModelViewer owns the native Filament resources and destroys itself
        // when its SurfaceView is detached from the window. Avoid a second
        // destroy here, which can race Android's detach callback.
    }

    companion object {
        private fun number(map: Map<String, Any?>, key: String, fallback: Double): Double {
            return (map[key] as? Number)?.toDouble() ?: fallback
        }
    }
}

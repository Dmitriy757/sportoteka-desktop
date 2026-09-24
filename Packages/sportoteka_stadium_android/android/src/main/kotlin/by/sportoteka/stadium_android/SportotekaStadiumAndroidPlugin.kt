package by.sportoteka.stadium_android

import android.util.Log

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
    // STADIUM_SCENE_FIX66
    private var fix66SceneRepairApplied = false
    private var fix66CaptureRequested = false

    // STADIUM_VISIBILITY_FIX65
    private var fix65VisibilityApplied = false
    private var fix65FrameCaptureRequested = false


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

private var fix63FrameCounter = 0L
    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (disposed) return
            choreographer.postFrameCallback(this)
            try {
                val rendered = modelViewer.render(frameTimeNanos)
            fix63FrameCounter++
            if (fix63FrameCounter == 1L || fix63FrameCounter % 60L == 0L) {
                Log.i("SportotekaStadium", "FIX63 rendered frame=$fix63FrameCounter progress=${modelViewer.progress}")
                val fix64Asset = modelViewer.asset
                var fix64RenderableCount = 0
                if (fix64Asset != null) {
                    val fix64Rm = modelViewer.engine.renderableManager
                    for (fix64Entity in fix64Asset.entities) {
                        if (fix64Rm.hasComponent(fix64Entity)) fix64RenderableCount++
                    }
                }
                Log.i("SportotekaStadium", "FIX64 renderables=$fix64RenderableCount progress=${modelViewer.progress}")
                if (!fix66SceneRepairApplied && modelViewer.progress >= 0.999f) {
                    val fix66Asset = modelViewer.asset
                    val fix66Scene = modelViewer.scene
                    val fix66View = modelViewer.view
                    val fix66Camera = modelViewer.camera
                    var fix66AssetRenderables = 0
                    var fix66InSceneRenderables = 0
                    if (fix66Asset != null) {
                        val fix66Rm = modelViewer.engine.renderableManager
                        for (fix66Entity in fix66Asset.entities) {
                            if (fix66Rm.hasComponent(fix66Entity)) {
                                fix66AssetRenderables++
                                if (fix66Scene.hasEntity(fix66Entity)) {
                                    fix66InSceneRenderables++
                                }
                            }
                        }
                    }
                    Log.i(
                        "SportotekaStadium",
                        "FIX66 before scene repair sceneEntities=${fix66Scene.entityCount} " +
                            "sceneRenderables=${fix66Scene.renderableCount} sceneLights=${fix66Scene.lightCount} " +
                            "assetRenderables=$fix66AssetRenderables inScene=$fix66InSceneRenderables " +
                            "viewSceneSame=${fix66View.scene === fix66Scene} viewHasCamera=${fix66View.hasCamera()}"
                    )
                
                    fix66View.scene = fix66Scene
                    fix66View.camera = fix66Camera
                    if (fix66Asset != null && fix66InSceneRenderables < fix66AssetRenderables) {
                        fix66Scene.addEntities(fix66Asset.entities)
                        if (fix66Asset.lightEntities.isNotEmpty()) {
                            fix66Scene.addEntities(fix66Asset.lightEntities)
                        }
                    }
                
                    modelViewer.transformToUnitCube()
                    val fix66Vp = fix66View.viewport
                    val fix66Aspect = if (fix66Vp.height > 0) {
                        fix66Vp.width.toDouble() / fix66Vp.height.toDouble()
                    } else {
                        1.5
                    }
                    fix66Camera.setProjection(
                        45.0,
                        fix66Aspect,
                        0.05,
                        1000.0,
                        com.google.android.filament.Camera.Fov.VERTICAL
                    )
                    fix66Camera.lookAt(
                        0.0, 1.20, 1.50,
                        0.0, 0.00, -4.0,
                        0.0, 1.0, 0.0
                    )
                    fix66View.setVisibleLayers(0xFF, 0xFF)
                    fix66View.setFrustumCullingEnabled(false)
                    fix66Scene.indirectLight?.intensity = 50000.0f
                    fix66Scene.skybox = null
                    fix66SceneRepairApplied = true
                
                    var fix66AfterInScene = 0
                    if (fix66Asset != null) {
                        val fix66Rm2 = modelViewer.engine.renderableManager
                        for (fix66Entity in fix66Asset.entities) {
                            if (fix66Rm2.hasComponent(fix66Entity) && fix66Scene.hasEntity(fix66Entity)) {
                                fix66AfterInScene++
                            }
                        }
                    }
                    Log.i(
                        "SportotekaStadium",
                        "FIX66 scene repair applied sceneEntities=${fix66Scene.entityCount} " +
                            "sceneRenderables=${fix66Scene.renderableCount} inSceneAfter=$fix66AfterInScene " +
                            "viewport=${fix66Vp.width}x${fix66Vp.height} aspect=$fix66Aspect"
                    )
                }
                
                if (fix66SceneRepairApplied && !fix66CaptureRequested && fix63FrameCounter >= 120L) {
                    fix66CaptureRequested = true
                    modelViewer.debugGetNextFrameCallback { bitmap ->
                        try {
                            val w = bitmap.width
                            val h = bitmap.height
                            val bg = bitmap.getPixel(0, 0)
                            var sampled = 0
                            var different = 0
                            var minX = w
                            var minY = h
                            var maxX = -1
                            var maxY = -1
                            var y = 0
                            while (y < h) {
                                var x = 0
                                while (x < w) {
                                    val px = bitmap.getPixel(x, y)
                                    val dr = kotlin.math.abs(android.graphics.Color.red(px) - android.graphics.Color.red(bg))
                                    val dg = kotlin.math.abs(android.graphics.Color.green(px) - android.graphics.Color.green(bg))
                                    val db = kotlin.math.abs(android.graphics.Color.blue(px) - android.graphics.Color.blue(bg))
                                    if (dr + dg + db > 18) {
                                        different++
                                        if (x < minX) minX = x
                                        if (y < minY) minY = y
                                        if (x > maxX) maxX = x
                                        if (y > maxY) maxY = y
                                    }
                                    sampled++
                                    x += 8
                                }
                                y += 8
                            }
                            Log.i(
                                "SportotekaStadium",
                                "FIX66 framebuffer ${w}x${h} sampled=$sampled different=$different " +
                                    "bbox=[$minX,$minY,$maxX,$maxY] bg=$bg"
                            )
                        } catch (t: Throwable) {
                            Log.e("SportotekaStadium", "FIX66 framebuffer diagnostic failed", t)
                        }
                    }
                }

                if (!fix65VisibilityApplied && modelViewer.progress >= 0.999f) {
                    modelViewer.view.setVisibleLayers(0xFF, 0xFF)
                    modelViewer.view.setFrustumCullingEnabled(false)
                    val fix65Asset = modelViewer.asset
                    var fix65Changed = 0
                    if (fix65Asset != null) {
                        val fix65Rm = modelViewer.engine.renderableManager
                        for (fix65Entity in fix65Asset.entities) {
                            if (fix65Rm.hasComponent(fix65Entity)) {
                                val fix65Instance = fix65Rm.getInstance(fix65Entity)
                                fix65Rm.setLayerMask(fix65Instance, 0xFF, 0x01)
                                fix65Rm.setCulling(fix65Instance, false)
                                fix65Changed++
                            }
                        }
                    }
                    fix65VisibilityApplied = true
                    Log.i(
                        "SportotekaStadium",
                        "FIX65 visibility forced renderables=$fix65Changed " +
                            "visibleLayers=${modelViewer.view.visibleLayers} frustumCulling=false"
                    )
                }
                if (fix65VisibilityApplied && !fix65FrameCaptureRequested) {
                    fix65FrameCaptureRequested = true
                    modelViewer.debugGetNextFrameCallback { bitmap ->
                        try {
                            val w = bitmap.width
                            val h = bitmap.height
                            val bg = bitmap.getPixel(0, 0)
                            var sampled = 0
                            var different = 0
                            var y = 0
                            while (y < h) {
                                var x = 0
                                while (x < w) {
                                    val px = bitmap.getPixel(x, y)
                                    val dr = kotlin.math.abs(android.graphics.Color.red(px) - android.graphics.Color.red(bg))
                                    val dg = kotlin.math.abs(android.graphics.Color.green(px) - android.graphics.Color.green(bg))
                                    val db = kotlin.math.abs(android.graphics.Color.blue(px) - android.graphics.Color.blue(bg))
                                    if (dr + dg + db > 18) different++
                                    sampled++
                                    x += 16
                                }
                                y += 16
                            }
                            Log.i(
                                "SportotekaStadium",
                                "FIX65 framebuffer ${w}x${h} sampled=$sampled differentFromCorner=$different bg=$bg"
                            )
                        } catch (t: Throwable) {
                            Log.e("SportotekaStadium", "FIX65 framebuffer diagnostic failed", t)
                        }
                    }
                }

            }
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
            clearColor = doubleArrayOf((0.149f).toDouble(), (0.275f).toDouble(), (0.227f).toDouble(), (1.0f).toDouble())
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
                        // STADIUM_AUTOFIT_FIX60
                        modelViewer.transformToUnitCube()
                        // STADIUM_CAMERA_FIX64
                        val fix64Viewport = modelViewer.view.viewport
                        val fix64Aspect = if (fix64Viewport.height > 0) {
                            fix64Viewport.width.toDouble() / fix64Viewport.height.toDouble()
                        } else {
                            1.5
                        }
                        modelViewer.camera.setLensProjection(28.0, fix64Aspect, 0.05, 1000.0)
                        modelViewer.camera.lookAt(
                            0.0, 1.65, 0.80,
                            0.0, -0.10, -4.0,
                            0.0, 1.0, 0.0
                        )
                        Log.i(
                            "SportotekaStadium",
                            "FIX64 camera locked eye=[0.0,1.65,0.80] target=[0.0,-0.10,-4.0] " +
                                "viewport=${fix64Viewport.width}x${fix64Viewport.height} aspect=$fix64Aspect"
                        )

                        Choreographer.getInstance().removeFrameCallback(frameCallback)
                        Choreographer.getInstance().postFrameCallback(frameCallback)
                        Log.i("SportotekaStadium", "FIX63 render callback STARTED: frameCallback")
                        Log.i("SportotekaStadium", "FIX60 GLB loaded + transformToUnitCube applied")
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:sportoteka/presentation/service_screens/ring_usage_screen.dart';

class SportotekaRingBanner extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onDetails;
  final VoidCallback? onBuy;
  final EdgeInsetsGeometry padding;

  const SportotekaRingBanner({
    super.key,
    required this.imageUrl,
    this.onDetails,
    this.onBuy,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  static const _brandBlue = Color(0xFF0057FF);
  static const _brandCyan = Color(0xFF00C6FF);
  static const _bannerHeight = 220.0;

  void _openDetails() {
    if (onDetails != null) {
      onDetails!.call();
      return;
    }
    Get.to(() => const RingUsageScreen());
  }

  void _buy(BuildContext context) {
    if (onBuy != null) {
      onBuy!.call();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Функция покупки будет доступна soon"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            height: _bannerHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [_brandBlue, _brandCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _brandBlue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                _buildBackgroundGlow(),
                _buildImageSection(constraints.maxWidth),
                _buildContentSection(constraints.maxWidth),
                _buildTopShine(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -60,
          child: _GlowBlob(size: 200, opacity: 0.25),
        ),
        Positioned(
          bottom: -100,
          right: -50,
          child: _GlowBlob(size: 250, opacity: 0.2),
        ),
      ],
    );
  }

  Widget _buildImageSection(double totalWidth) {
    final imageWidth = (totalWidth * 0.48).clamp(160.0, 260.0);
    
    return Positioned(
      right: -15,
      top: -10,
      bottom: -10,
      width: imageWidth,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(30),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main image
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              placeholder: (_, __) => Container(
                color: Colors.white.withOpacity(0.1),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.white.withOpacity(0.1),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Soft gradient overlay for better text contrast
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            
            // Subtle vignette effect
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.centerRight,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection(double totalWidth) {
    final contentWidth = totalWidth * 0.55;
    
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: contentWidth,
      child: GestureDetector(
        onTap: _openDetails,
        child: _GlassPanel(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTag(),
                const SizedBox(height: 16),
                _buildFeatures(),
                const Spacer(),
                _buildButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sports_soccer,
            size: 14,
            color: Colors.white,
          ),
          SizedBox(width: 6),
          Text(
            "Футбольный трекер",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    const features = [
      "Датчик движения",
      "Анализ нагрузок",
      "Отчёты тренеру",
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                feature,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            text: "Подробнее",
            onPressed: _openDetails,
            type: _ButtonType.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            text: "Купить",
            onPressed: () => _buy(Get.context!),
            type: _ButtonType.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildTopShine() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// MARK: - Supporting Widgets

class _GlowBlob extends StatelessWidget {
  final double size;
  final double opacity;
  
  const _GlowBlob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadiusGeometry borderRadius;
  
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

enum _ButtonType { primary, outline }

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final _ButtonType type;
  
  const _ActionButton({
    required this.text,
    required this.onPressed,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      _ButtonType.primary => _PrimaryButton(text: text, onPressed: onPressed),
      _ButtonType.outline => _OutlineButton(text: text, onPressed: onPressed),
    };
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  
  const _PrimaryButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0057FF),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      child: Text(text),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  
  const _OutlineButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      child: Text(text),
    );
  }
}
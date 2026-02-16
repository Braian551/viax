import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class DocumentsLoadingShimmer extends StatelessWidget {
  const DocumentsLoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Espacio para AppBar y Stats Header
          SizedBox(height: MediaQuery.of(context).padding.top + 70),
          
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title: "Resumen General"
                  Container(
                    width: 150,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stats Grid (2 rows)
                  Row(
                    children: [
                      Expanded(child: _buildStatCardPlaceholder()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCardPlaceholder()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCardPlaceholder()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCardPlaceholder()),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Filter Section
                  Container(
                    width: 120,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPillPlaceholder(width: 80),
                      const SizedBox(width: 8),
                      _buildPillPlaceholder(width: 100),
                      const SizedBox(width: 8),
                      _buildPillPlaceholder(width: 100),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Driver Cards List
                  _buildDriverCardPlaceholder(),
                  const SizedBox(height: 12),
                  _buildDriverCardPlaceholder(),
                  const SizedBox(height: 12),
                  _buildDriverCardPlaceholder(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardPlaceholder() {
    return Container(
      height: 120, // Approx height of stat card
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildPillPlaceholder({required double width}) {
    return Container(
      width: width,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildDriverCardPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Name + Badge
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, color: Colors.black),
                    const SizedBox(height: 6),
                    Container(width: 150, height: 10, color: Colors.black),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 70,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Info Rows (License/Plate)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 40, height: 8, color: Colors.black),
                    const SizedBox(height: 4),
                    Container(width: 80, height: 10, color: Colors.black),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 40, height: 8, color: Colors.black),
                    const SizedBox(height: 4),
                    Container(width: 80, height: 10, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(width: 60, height: 8, color: Colors.black),
              Container(width: 30, height: 8, color: Colors.black),
            ],
          ),
          const SizedBox(height: 6),
          Container(width: double.infinity, height: 6, color: Colors.black),
          
          const SizedBox(height: 16),
          
          // Buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

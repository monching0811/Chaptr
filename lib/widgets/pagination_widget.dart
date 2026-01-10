import 'package:flutter/material.dart';

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;
  final Color? activeColor;
  final Color? inactiveColor;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final active = activeColor ?? const Color(0xFFFFEB3B);
    final inactive = inactiveColor ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
            color: currentPage > 1 ? Colors.black : Colors.grey,
          ),

          // Page numbers
          ...List.generate(
            totalPages.clamp(0, 7), // Show max 7 page buttons
            (index) {
              int pageNum;
              
              // Calculate which page numbers to show
              if (totalPages <= 7) {
                pageNum = index + 1;
              } else {
                // Show pages around current page
                int startPage = (currentPage - 3).clamp(1, totalPages - 6);
                pageNum = startPage + index;
              }

              final isCurrentPage = pageNum == currentPage;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: InkWell(
                  onTap: () => onPageChanged(pageNum),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentPage ? active : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrentPage ? active : inactive,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          color: isCurrentPage ? Colors.black : inactive,
                          fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Show ellipsis if there are more pages
          if (totalPages > 7 && currentPage < totalPages - 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                '...',
                style: TextStyle(color: inactive, fontSize: 16),
              ),
            ),

          // Show last page if not visible
          if (totalPages > 7 && currentPage < totalPages - 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: () => onPageChanged(totalPages),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: currentPage == totalPages ? active : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentPage == totalPages ? active : inactive,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$totalPages',
                      style: TextStyle(
                        color: currentPage == totalPages ? Colors.black : inactive,
                        fontWeight: currentPage == totalPages ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Next button
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
            color: currentPage < totalPages ? Colors.black : Colors.grey,
          ),
        ],
      ),
    );
  }
}

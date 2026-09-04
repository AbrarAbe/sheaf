import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaperStack extends StatelessWidget {
  const PaperStack({
    super.key,
    required this.isLight,
    required this.primary,
    required this.card,
    required this.hairline,
  });
  final bool isLight;
  final Color primary;
  final Color card;
  final Color hairline;

  @override
  Widget build(BuildContext context) {
    // Three layered paper sheets, offset — the quire metaphor.
    // Top sheet carries a single ink stroke (primary) as a signature.
    return SizedBox(
      width: 120,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Back sheet
          Positioned(
            top: 12,
            child: Transform.rotate(
              angle: -0.07,
              child: Container(
                width: 96,
                height: 68,
                decoration: BoxDecoration(
                  color: card.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hairline),
                ),
              ),
            ),
          ),
          // Middle sheet
          Positioned(
            top: 6,
            child: Transform.rotate(
              angle: 0.05,
              child: Container(
                width: 96,
                height: 68,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hairline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Front sheet
          Container(
            width: 96,
            height: 68,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hairline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 8,
                  width: 42,
                  decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 6),
                ...List.generate(
                  3,
                  (i) => Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: hairline.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2C94C).withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '#quire',
                      style: GoogleFonts.splineSansMono(
                        fontSize: 7,
                        letterSpacing: 0.4,
                        color: const Color(0xFF7A5E00),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

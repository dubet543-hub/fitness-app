import 'dart:math';
import 'package:flutter/material.dart';

const _kBg      = Color(0xFF0D1117);
const _kSurface = Color(0xFF161B22);
const _kCard    = Color(0xFF1C2333);
const _kBorder  = Color(0xFF30363D);
const _kTxtP    = Color(0xFFE6EDF3);
const _kTxtS    = Color(0xFF8B949E);

// ── Data Point ────────────────────────────────────────────────────────────────

class _LP {
  final String d;       // label "dd/MM"
  final double load;    // session load that day
  final double acute;   // 7-day rolling avg (sum/7)
  final double chronic; // EWMA of acute values (alpha=2/29)
  final double acwr;
  final double z;
  const _LP(this.d, this.load, this.acute, this.chronic, this.acwr, this.z);
}

// ── Static Dataset (PDF: Workload Monitoring – Cleaned Daily Data) ─────────────

// ─── Athlete 1 (ATS-2025-001) ─────────────────────────────────────────────────

const _a1Train = <_LP>[
  _LP('19/03', 0, 0.0, 0.0, 0.00, 0.00),
  _LP('21/03', 135, 19.3, 1.3, 14.50, 1.98),
  _LP('22/03', 0, 19.3, 2.6, 7.51, -0.04),
  _LP('23/03', 0, 19.3, 3.7, 5.18, -0.06),
  _LP('24/03', 0, 19.3, 4.8, 4.02, -0.09),
  _LP('25/03', 0, 19.3, 5.8, 3.33, -0.12),
  _LP('26/03', 0, 19.3, 6.7, 2.87, -0.14),
  _LP('27/03', 141, 39.4, 9.0, 4.39, 2.21),
  _LP('29/03', 0, 20.1, 9.7, 2.07, -0.17),
  _LP('31/03', 624, 109.3, 16.6, 6.58, 3.26),
  _LP('01/04', 0, 109.3, 23.0, 4.75, -0.13),
  _LP('02/04', 0, 109.3, 29.0, 3.77, -0.17),
  _LP('03/04', 0, 89.1, 33.1, 2.69, -0.20),
  _LP('04/04', 0, 89.1, 37.0, 2.41, -0.23),
  _LP('05/04', 0, 89.1, 40.6, 2.20, -0.26),
  _LP('06/04', 0, 89.1, 43.9, 2.03, -0.29),
  _LP('07/04', 205, 29.3, 42.9, 0.68, 1.06),
  _LP('08/04', 215, 60.0, 44.1, 1.36, 1.12),
  _LP('09/04', 116, 76.6, 46.3, 1.65, 0.47),
  _LP('10/04', 0, 76.6, 48.4, 1.58, -0.33),
  _LP('11/04', 747, 183.3, 57.7, 3.18, 3.41),
  _LP('12/04', 155, 205.4, 67.9, 3.03, 0.44),
  _LP('13/04', 236, 239.1, 79.7, 3.00, 0.80),
  _LP('14/04', 0, 209.9, 88.7, 2.37, -0.46),
  _LP('15/04', 0, 179.1, 94.9, 1.89, -0.50),
  _LP('16/04', 392, 218.6, 103.5, 2.11, 1.48),
  _LP('17/04', 0, 218.6, 111.4, 1.96, -0.58),
  _LP('18/04', 0, 111.9, 111.4, 1.00, -0.59),
  _LP('19/04', 0, 89.7, 109.9, 0.82, -0.59),
  _LP('20/04', 0, 56.0, 106.2, 0.53, -0.57),
  _LP('21/04', 0, 56.0, 102.7, 0.55, -0.56),
  _LP('22/04', 270, 94.6, 102.2, 0.93, 0.92),
  _LP('23/04', 192, 66.0, 99.7, 0.66, 0.51),
  _LP('24/04', 172, 90.6, 99.1, 0.91, 0.41),
  _LP('25/04', 135, 109.9, 99.8, 1.10, 0.20),
  _LP('26/04', 329, 156.9, 103.7, 1.51, 1.27),
  _LP('27/04', 0, 156.9, 107.4, 1.46, -0.61),
  _LP('28/04', 0, 156.9, 110.8, 1.42, -0.64),
  _LP('29/04', 0, 118.3, 111.3, 1.06, -0.64),
  _LP('30/04', 0, 90.9, 109.9, 0.83, -0.64),
  _LP('01/05', 178, 91.7, 108.7, 0.84, 0.41),
  _LP('02/05', 603, 158.6, 112.1, 1.41, 2.67),
  _LP('03/05', 0, 111.6, 112.1, 1.00, -0.61),
  _LP('04/05', 0, 111.6, 112.0, 1.00, -0.62),
  _LP('05/05', 135, 130.9, 113.3, 1.15, 0.12),
  _LP('06/05', 90, 143.7, 115.4, 1.25, -0.14),
  _LP('07/05', 192, 171.1, 119.3, 1.43, 0.41),
];

const _a1Skill = <_LP>[
  _LP('19/03', 560, 80.0, 80.0, 1.00, 0.00),
  _LP('21/03', 0, 80.0, 80.0, 1.00, -0.29),
  _LP('22/03', 0, 80.0, 80.0, 1.00, -0.30),
  _LP('23/03', 0, 80.0, 80.0, 1.00, -0.33),
  _LP('24/03', 54, 87.7, 80.5, 1.09, -0.12),
  _LP('25/03', 288, 128.9, 83.9, 1.54, 0.97),
  _LP('26/03', 72, 59.1, 82.2, 0.72, -0.05),
  _LP('27/03', 0, 59.1, 80.6, 0.73, -0.43),
  _LP('29/03', 288, 100.3, 81.9, 1.22, 1.11),
  _LP('31/03', 0, 92.6, 82.7, 1.12, -0.46),
  _LP('01/04', 294, 93.4, 83.4, 1.12, 1.17),
  _LP('02/04', 0, 83.1, 83.4, 1.00, -0.47),
  _LP('03/04', 450, 147.4, 87.8, 1.68, 1.91),
  _LP('04/04', 0, 147.4, 91.9, 1.60, -0.49),
  _LP('05/04', 0, 106.3, 92.9, 1.14, -0.50),
  _LP('06/04', 135, 125.6, 95.2, 1.32, 0.22),
  _LP('07/04', 228, 158.1, 99.5, 1.59, 0.74),
  _LP('08/04', 36, 121.3, 101.0, 1.20, -0.38),
  _LP('09/04', 36, 126.4, 102.8, 1.23, -0.40),
  _LP('10/04', 180, 87.9, 101.7, 0.86, 0.48),
  _LP('11/04', 0, 87.9, 100.8, 0.87, -0.62),
  _LP('12/04', 84, 99.9, 100.7, 0.99, -0.11),
  _LP('13/04', 112, 96.6, 100.4, 0.96, 0.07),
  _LP('14/04', 270, 102.6, 100.6, 1.02, 1.09),
  _LP('15/04', 96, 111.1, 101.3, 1.10, -0.03),
  _LP('16/04', 310, 150.3, 104.7, 1.44, 1.34),
  _LP('17/04', 160, 147.4, 107.6, 1.37, 0.35),
  _LP('18/04', 160, 170.3, 112.0, 1.52, 0.33),
  _LP('19/04', 90, 171.1, 116.0, 1.47, -0.18),
  _LP('20/04', 36, 160.3, 119.1, 1.35, -0.58),
  _LP('21/04', 0, 121.7, 119.3, 1.02, -0.83),
  _LP('22/04', 0, 108.0, 118.5, 0.91, -0.83),
  _LP('23/04', 0, 63.7, 114.7, 0.56, -0.81),
  _LP('24/04', 0, 40.9, 109.6, 0.37, -0.77),
  _LP('25/04', 120, 35.1, 104.5, 0.34, 0.11),
  _LP('26/04', 0, 22.3, 98.8, 0.23, -0.71),
  _LP('27/04', 72, 27.4, 93.9, 0.29, -0.16),
  _LP('28/04', 126, 45.4, 90.5, 0.50, 0.26),
  _LP('29/04', 80, 56.9, 88.2, 0.64, -0.06),
  _LP('30/04', 135, 76.1, 87.4, 0.87, 0.36),
  _LP('01/05', 0, 76.1, 86.6, 0.88, -0.66),
  _LP('02/05', 72, 69.3, 85.4, 0.81, -0.10),
  _LP('03/05', 0, 69.3, 84.3, 0.82, -0.65),
  _LP('04/05', 0, 59.0, 82.6, 0.71, -0.64),
  _LP('05/05', 124, 58.7, 80.9, 0.73, 0.34),
  _LP('06/05', 480, 115.9, 83.3, 1.39, 2.88),
  _LP('07/05', 420, 156.6, 88.4, 1.77, 2.31),
];

const _a1Total = <_LP>[
  _LP('19/03', 560, 80.0, 80.0, 1.00, 0.00),
  _LP('21/03', 135, 99.3, 81.3, 1.22, 0.25),
  _LP('22/03', 0, 99.3, 82.6, 1.20, -0.35),
  _LP('23/03', 0, 99.3, 83.7, 1.19, -0.36),
  _LP('24/03', 54, 107.0, 85.3, 1.25, -0.15),
  _LP('25/03', 288, 148.1, 89.7, 1.65, 0.99),
  _LP('26/03', 72, 78.4, 88.9, 0.88, -0.09),
  _LP('27/03', 141, 98.6, 89.6, 1.10, 0.29),
  _LP('29/03', 288, 120.4, 91.7, 1.31, 1.15),
  _LP('31/03', 624, 201.9, 99.3, 2.03, 2.48),
  _LP('01/04', 294, 202.7, 106.4, 1.90, 0.92),
  _LP('02/04', 0, 192.4, 112.3, 1.71, -0.55),
  _LP('03/04', 450, 236.6, 120.9, 1.96, 1.59),
  _LP('04/04', 0, 236.6, 128.9, 1.84, -0.62),
  _LP('05/04', 0, 195.4, 133.5, 1.46, -0.65),
  _LP('06/04', 135, 214.7, 139.1, 1.54, -0.02),
  _LP('07/04', 433, 187.4, 142.4, 1.32, 1.43),
  _LP('08/04', 251, 181.3, 145.1, 1.25, 0.54),
  _LP('09/04', 152, 203.0, 149.1, 1.36, 0.02),
  _LP('10/04', 180, 164.4, 150.1, 1.10, 0.16),
  _LP('11/04', 747, 271.1, 158.5, 1.71, 2.71),
  _LP('12/04', 239, 305.3, 168.6, 1.81, 0.33),
  _LP('13/04', 348, 335.7, 180.1, 1.86, 0.80),
  _LP('14/04', 270, 312.4, 189.3, 1.65, 0.40),
  _LP('15/04', 96, 290.3, 196.2, 1.48, -0.50),
  _LP('16/04', 702, 368.9, 208.1, 1.77, 2.27),
  _LP('17/04', 160, 366.0, 219.0, 1.67, -0.28),
  _LP('18/04', 160, 282.1, 223.4, 1.26, -0.30),
  _LP('19/04', 90, 260.9, 226.0, 1.15, -0.65),
  _LP('20/04', 36, 216.3, 225.3, 0.96, -0.91),
  _LP('21/04', 0, 177.7, 222.0, 0.80, -1.06),
  _LP('22/04', 270, 202.6, 220.7, 0.92, 0.24),
  _LP('23/04', 192, 129.7, 214.4, 0.61, -0.11),
  _LP('24/04', 172, 131.4, 208.7, 0.63, -0.18),
  _LP('25/04', 255, 145.0, 204.3, 0.71, 0.26),
  _LP('26/04', 329, 179.1, 202.6, 0.88, 0.65),
  _LP('27/04', 72, 184.3, 201.3, 0.92, -0.66),
  _LP('28/04', 126, 202.3, 201.4, 1.00, -0.39),
  _LP('29/04', 80, 175.1, 199.6, 0.88, -0.62),
  _LP('30/04', 135, 167.0, 197.3, 0.85, -0.33),
  _LP('01/05', 178, 167.9, 195.3, 0.86, -0.09),
  _LP('02/05', 675, 227.9, 197.5, 1.15, 2.41),
  _LP('03/05', 0, 180.9, 196.4, 0.92, -0.99),
  _LP('04/05', 0, 170.6, 194.6, 0.88, -0.98),
  _LP('05/05', 259, 189.6, 194.2, 0.98, 0.33),
  _LP('06/05', 570, 259.6, 198.8, 1.31, 1.84),
  _LP('07/05', 612, 327.7, 207.6, 1.58, 1.95),
];

// ─── Athlete 2 (ATS-2025-002) ─────────────────────────────────────────────────

const _a2Train = <_LP>[
  _LP('21/03', 990, 141.4, 141.4, 1.00, 0.00),
  _LP('22/03', 0, 141.4, 141.4, 1.00, -0.29),
  _LP('23/03', 100, 155.7, 142.4, 1.09, -0.10),
  _LP('24/03', 96, 169.4, 144.3, 1.17, -0.12),
  _LP('25/03', 0, 169.4, 146.0, 1.16, -0.39),
  _LP('26/03', 390, 225.1, 151.5, 1.49, 0.68),
  _LP('27/03', 448, 289.1, 161.0, 1.80, 0.87),
  _LP('28/03', 150, 169.1, 161.5, 1.05, -0.04),
  _LP('29/03', 0, 169.1, 162.1, 1.04, -0.53),
  _LP('30/03', 540, 232.0, 166.9, 1.39, 1.22),
  _LP('31/03', 170, 242.6, 172.1, 1.41, -0.01),
  _LP('01/04', 96, 256.3, 177.9, 1.44, -0.29),
  _LP('02/04', 0, 200.6, 179.5, 1.12, -0.64),
  _LP('03/04', 0, 136.6, 176.5, 0.77, -0.64),
  _LP('04/04', 0, 115.1, 172.3, 0.67, -0.63),
  _LP('05/04', 0, 115.1, 168.3, 0.68, -0.63),
  _LP('06/04', 458, 103.4, 163.9, 0.63, 1.10),
  _LP('07/04', 588, 163.1, 163.8, 1.00, 1.54),
  _LP('08/04', 385, 204.4, 166.6, 1.23, 0.81),
  _LP('09/04', 510, 277.3, 174.2, 1.59, 1.24),
  _LP('10/04', 80, 288.7, 182.1, 1.59, -0.38),
  _LP('11/04', 480, 357.3, 194.2, 1.84, 1.08),
  _LP('12/04', 0, 357.3, 205.5, 1.74, -0.78),
  _LP('13/04', 540, 369.0, 216.7, 1.70, 1.22),
  _LP('14/04', 445, 348.6, 225.8, 1.54, 0.84),
  _LP('15/04', 600, 379.3, 236.4, 1.60, 1.37),
  _LP('16/04', 335, 354.3, 244.5, 1.45, 0.35),
  _LP('17/04', 105, 357.9, 252.4, 1.42, -0.57),
  _LP('18/04', 390, 345.0, 258.7, 1.33, 0.52),
  _LP('20/04', 371, 320.9, 263.0, 1.22, 0.43),
  _LP('21/04', 186, 283.9, 264.5, 1.07, -0.32),
  _LP('22/04', 240, 232.4, 262.3, 0.89, -0.09),
  _LP('23/04', 301, 227.6, 259.9, 0.88, 0.17),
  _LP('24/04', 320, 258.3, 259.8, 0.99, 0.25),
  _LP('25/04', 0, 202.6, 255.8, 0.79, -1.08),
  _LP('26/04', 0, 202.6, 252.1, 0.80, -1.06),
  _LP('27/04', 178, 175.0, 246.8, 0.71, -0.29),
  _LP('28/04', 0, 148.4, 240.0, 0.62, -1.02),
  _LP('29/04', 245, 149.1, 233.8, 0.64, 0.05),
  _LP('30/04', 258, 143.0, 227.5, 0.63, 0.13),
  _LP('01/05', 300, 140.1, 221.5, 0.63, 0.35),
  _LP('02/05', 229, 172.9, 218.1, 0.79, 0.05),
  _LP('03/05', 0, 172.9, 215.0, 0.80, -0.96),
  _LP('04/05', 270, 186.0, 213.0, 0.87, 0.26),
  _LP('05/05', 236, 219.7, 213.5, 1.03, 0.10),
  _LP('06/05', 270, 223.3, 214.1, 1.04, 0.26),
  _LP('07/05', 258, 223.3, 214.8, 1.04, 0.20),
];

const _a2Skill = <_LP>[
  _LP('19/03', 560, 80.0, 80.0, 1.00, 0.00),
  _LP('21/03', 0, 80.0, 80.0, 1.00, -0.29),
  _LP('22/03', 0, 80.0, 80.0, 1.00, -0.30),
  _LP('24/03', 216, 110.9, 82.1, 1.35, 0.58),
  _LP('25/03', 525, 185.9, 89.3, 2.08, 1.79),
  _LP('26/03', 0, 105.9, 90.4, 1.17, -0.37),
  _LP('27/03', 0, 105.9, 91.5, 1.16, -0.39),
  _LP('28/03', 144, 126.4, 93.9, 1.35, 0.23),
  _LP('29/03', 504, 198.4, 101.1, 1.96, 1.73),
  _LP('30/03', 0, 198.4, 107.8, 1.84, -0.47),
  _LP('31/03', 0, 167.6, 111.9, 1.50, -0.49),
  _LP('01/04', 0, 92.6, 110.6, 0.84, -0.50),
  _LP('02/04', 0, 92.6, 109.4, 0.85, -0.50),
  _LP('03/04', 0, 92.6, 108.2, 0.86, -0.51),
  _LP('04/04', 0, 72.0, 105.7, 0.68, -0.50),
  _LP('05/04', 0, 0.0, 98.4, 0.00, -0.48),
  _LP('06/04', 0, 0.0, 91.6, 0.00, -0.46),
  _LP('07/04', 300, 42.9, 88.3, 0.49, 1.06),
  _LP('08/04', 280, 82.9, 87.9, 0.94, 0.97),
  _LP('09/04', 100, 97.1, 88.5, 1.10, 0.06),
  _LP('10/04', 270, 135.7, 91.8, 1.48, 0.94),
  _LP('11/04', 0, 135.7, 94.8, 1.43, -0.50),
  _LP('12/04', 0, 135.7, 97.6, 1.39, -0.52),
  _LP('13/04', 300, 178.6, 103.2, 1.73, 1.06),
  _LP('14/04', 360, 187.1, 109.0, 1.72, 1.34),
  _LP('15/04', 360, 198.6, 115.2, 1.72, 1.30),
  _LP('16/04', 280, 224.3, 122.7, 1.83, 0.84),
  _LP('17/04', 240, 220.0, 129.4, 1.70, 0.60),
  _LP('18/04', 0, 220.0, 135.7, 1.62, -0.74),
  _LP('20/04', 150, 198.6, 140.0, 1.42, 0.06),
  _LP('21/04', 30, 151.4, 140.8, 1.08, -0.62),
  _LP('22/04', 45, 106.4, 138.4, 0.77, -0.53),
  _LP('23/04', 80, 77.9, 134.2, 0.58, -0.31),
  _LP('24/04', 150, 65.0, 129.5, 0.50, 0.12),
  _LP('25/04', 120, 82.1, 126.2, 0.65, -0.04),
  _LP('26/04', 180, 107.9, 124.9, 0.86, 0.33),
  _LP('27/04', 12, 88.1, 122.4, 0.72, -0.67),
  _LP('28/04', 0, 83.9, 119.7, 0.70, -0.73),
  _LP('29/04', 0, 77.4, 116.8, 0.66, -0.71),
  _LP('30/04', 180, 91.7, 115.1, 0.80, 0.40),
  _LP('01/05', 175, 95.3, 113.7, 0.84, 0.38),
  _LP('02/05', 100, 92.4, 112.3, 0.82, -0.08),
  _LP('03/05', 0, 66.7, 109.1, 0.61, -0.69),
  _LP('04/05', 0, 65.0, 106.1, 0.61, -0.67),
  _LP('05/05', 180, 90.7, 105.0, 0.86, 0.48),
  _LP('06/05', 90, 103.6, 104.9, 0.99, -0.10),
  _LP('07/05', 150, 99.3, 104.5, 0.95, 0.30),
];

const _a2Total = <_LP>[
  _LP('19/03', 560, 80.0, 80.0, 1.00, 0.00),
  _LP('21/03', 990, 221.4, 89.8, 2.47, 4.19),
  _LP('22/03', 0, 221.4, 98.8, 2.24, -0.24),
  _LP('23/03', 100, 235.7, 108.3, 2.18, -0.02),
  _LP('24/03', 312, 280.3, 120.1, 2.33, 0.54),
  _LP('25/03', 525, 355.3, 136.4, 2.61, 1.18),
  _LP('26/03', 390, 331.0, 149.8, 2.21, 0.79),
  _LP('27/03', 448, 395.0, 166.7, 2.37, 0.99),
  _LP('28/03', 294, 295.6, 175.6, 1.68, 0.44),
  _LP('29/03', 504, 367.6, 188.8, 1.95, 1.22),
  _LP('30/03', 540, 430.4, 205.5, 2.09, 1.34),
  _LP('31/03', 170, 410.1, 219.6, 1.87, -0.20),
  _LP('01/04', 96, 348.9, 228.5, 1.53, -0.52),
  _LP('02/04', 0, 293.1, 233.0, 1.26, -0.89),
  _LP('03/04', 0, 229.1, 232.7, 0.98, -0.87),
  _LP('04/04', 0, 187.1, 229.6, 0.82, -0.84),
  _LP('05/04', 0, 115.1, 221.7, 0.52, -0.81),
  _LP('06/04', 458, 103.4, 213.5, 0.48, 0.91),
  _LP('07/04', 888, 206.0, 213.0, 0.97, 2.31),
  _LP('08/04', 665, 287.3, 218.1, 1.32, 1.52),
  _LP('09/04', 610, 374.4, 228.9, 1.64, 1.30),
  _LP('10/04', 350, 424.4, 242.4, 1.75, 0.38),
  _LP('11/04', 480, 493.0, 259.7, 1.90, 0.78),
  _LP('12/04', 0, 493.0, 275.8, 1.79, -0.97),
  _LP('13/04', 840, 547.6, 294.5, 1.86, 1.85),
  _LP('14/04', 805, 535.7, 311.1, 1.72, 1.64),
  _LP('15/04', 960, 577.9, 329.5, 1.75, 2.00),
  _LP('16/04', 615, 578.6, 346.7, 1.67, 0.86),
  _LP('17/04', 345, 577.9, 362.7, 1.59, -0.06),
  _LP('18/04', 390, 565.0, 376.6, 1.50, 0.04),
  _LP('20/04', 521, 519.4, 386.5, 1.34, 0.45),
  _LP('21/04', 216, 435.3, 389.8, 1.12, -0.59),
  _LP('22/04', 285, 338.9, 386.3, 0.88, -0.35),
  _LP('23/04', 381, 305.4, 380.7, 0.80, 0.00),
  _LP('24/04', 470, 323.3, 376.8, 0.86, 0.33),
  _LP('25/04', 120, 284.7, 370.4, 0.77, -0.89),
  _LP('26/04', 180, 310.4, 366.3, 0.85, -0.66),
  _LP('27/04', 190, 263.1, 359.2, 0.73, -0.61),
  _LP('28/04', 0, 232.3, 350.4, 0.66, -1.24),
  _LP('29/04', 245, 226.6, 341.9, 0.66, -0.35),
  _LP('30/04', 438, 234.7, 334.5, 0.70, 0.38),
  _LP('01/05', 475, 235.4, 327.7, 0.72, 0.54),
  _LP('02/05', 329, 265.3, 323.4, 0.82, 0.02),
  _LP('03/05', 0, 239.6, 317.6, 0.75, -1.16),
  _LP('04/05', 270, 251.0, 313.0, 0.80, -0.16),
  _LP('05/05', 416, 310.4, 312.8, 0.99, 0.39),
  _LP('06/05', 360, 326.9, 313.8, 1.04, 0.17),
  _LP('07/05', 408, 322.6, 314.4, 1.03, 0.36),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class WorkloadMonitorScreen extends StatefulWidget {
  const WorkloadMonitorScreen({super.key});

  @override
  State<WorkloadMonitorScreen> createState() => _WMState();
}

class _WMState extends State<WorkloadMonitorScreen>
    with SingleTickerProviderStateMixin {

  int _athlete = 0; // 0 = ATS-2025-001, 1 = ATS-2025-002
  String _range = '28d';
  late final TabController _tabs;

  static DateTime _parseLP(String d) {
    final parts = d.split('/');
    return DateTime(2025, int.parse(parts[1]), int.parse(parts[0]));
  }

  List<_LP> _applyRange(List<_LP> all) {
    if (all.isEmpty || _range == '28d') return all;
    final last = _parseLP(all.last.d);
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (_range == 'today') {
      return all.where((p) => sameDay(_parseLP(p.d), last)).toList();
    }
    if (_range == 'yesterday') {
      final yest = last.subtract(const Duration(days: 1));
      return all.where((p) => sameDay(_parseLP(p.d), yest)).toList();
    }
    final days = _range == '1w' ? 6 : 13;
    final cutoff = last.subtract(Duration(days: days));
    return all.where((p) => !_parseLP(p.d).isBefore(cutoff)).toList();
  }

  List<_LP> get _train  => _applyRange(_athlete == 0 ? _a1Train  : _a2Train);
  List<_LP> get _skill  => _applyRange(_athlete == 0 ? _a1Skill  : _a2Skill);
  List<_LP> get _total  => _applyRange(_athlete == 0 ? _a1Total  : _a2Total);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: const Text('Workload Monitor',
            style: TextStyle(color: _kTxtP, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: false,
        iconTheme: const IconThemeData(color: _kTxtP),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _AthleteToggle(
              selected: _athlete,
              onChanged: (i) => setState(() => _athlete = i),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            const Divider(height: 1, color: _kBorder),
            TabBar(
              controller: _tabs,
              labelColor: const Color(0xFFFF6B35),
              unselectedLabelColor: _kTxtS,
              indicatorColor: const Color(0xFFFF6B35),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(icon: Icon(Icons.fitness_center_rounded, size: 16), text: 'Training'),
                Tab(icon: Icon(Icons.sports_cricket_rounded, size: 16), text: 'Skill'),
                Tab(icon: Icon(Icons.stacked_bar_chart_rounded, size: 16), text: 'Daily Total'),
              ],
            ),
          ]),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _FilterBar(
              selected: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SectionView(
                  data:         _train,
                  accentColor:  Colors.lightBlueAccent,
                  sectionTitle: 'Training Session Exertion',
                  barColor:     Colors.lightBlueAccent,
                ),
                _SectionView(
                  data:         _skill,
                  accentColor:  Colors.greenAccent,
                  sectionTitle: 'Skill Session Exertion',
                  barColor:     Colors.greenAccent,
                ),
                _SectionView(
                  data:         _total,
                  accentColor:  Colors.purpleAccent,
                  sectionTitle: 'Daily Total Load & Exertion',
                  barColor:     Colors.purpleAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterBar({required this.selected, required this.onChanged});

  static const _keys   = ['today', 'yesterday', '1w', '2w', '28d'];
  static const _labels = ['Today', 'Yesterday', '1 Week', '2 Weeks', '28 Days'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_keys.length, (i) {
          final active = selected == _keys[i];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(_keys[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFFF6B35) : _kCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? const Color(0xFFFF6B35) : _kBorder,
                  ),
                ),
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : _kTxtS,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Athlete Toggle ─────────────────────────────────────────────────────────────

class _AthleteToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _AthleteToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(label: 'ATS-001', active: selected == 0, onTap: () => onChanged(0)),
          _Pill(label: 'ATS-002', active: selected == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFF6B35) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : _kTxtS,
            )),
      ),
    );
  }
}

// ── Section View ──────────────────────────────────────────────────────────────

class _SectionView extends StatelessWidget {
  final List<_LP> data;
  final Color accentColor, barColor;
  final String sectionTitle;

  const _SectionView({
    required this.data,
    required this.accentColor,
    required this.sectionTitle,
    required this.barColor,
  });

  _LP get _last => data.last;

  // Session Exertion = ln(load) / ln(1000) × 10
  double get _exertion {
    final l = _last.load;
    if (l <= 0) return 0;
    return (log(l) / log(1000)) * 10;
  }

  // Target range from chronic: [chronic × 0.8, chronic × 1.3]
  int get _targetLow  => (_last.chronic * 0.8).round();
  int get _targetHigh => (_last.chronic * 1.3).round();

  Color _acwrColor(double v) {
    if (v <= 0)   return Colors.grey;
    if (v < 0.8)  return Colors.blueAccent;
    if (v <= 1.3) return Colors.greenAccent;
    if (v <= 1.5) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _acwrLabel(double v) {
    if (v <= 0)   return 'No Data';
    if (v < 0.8)  return 'Undertraining';
    if (v <= 1.3) return 'Sweet Spot';
    if (v <= 1.5) return 'Caution';
    return 'Danger Zone';
  }

  Color _loadGuidanceColor(double load, int low, int high) {
    if (load <= 0) return Colors.grey;
    if (load < low) return Colors.blueAccent;
    if (load <= high) return Colors.greenAccent;
    return Colors.orangeAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: _kTxtS)));
    }
    final acwr  = _last.acwr;
    final acCol = _acwrColor(acwr);
    final tLow  = _targetLow;
    final tHigh = _targetHigh;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section label ──────────────────────────────────────────────────
          Row(children: [
            Container(width: 3, height: 16, color: accentColor,
                margin: const EdgeInsets.only(right: 8)),
            Text(sectionTitle,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTxtP)),
          ]),
          const SizedBox(height: 12),

          // ── Key Metrics Row 1: Load, Exertion, Acute, Chronic ─────────────
          Row(children: [
            Expanded(child: _MetricCard(
              label: 'Session Load',
              value: _last.load.toStringAsFixed(0),
              color: accentColor,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: 'Exertion',
              value: _exertion.toStringAsFixed(1),
              color: Colors.pinkAccent,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: '7-day Acute',
              value: _last.acute.toStringAsFixed(0),
              color: Colors.lightBlueAccent,
            )),
          ]),
          const SizedBox(height: 10),

          // ── Key Metrics Row 2: Chronic, ACWR, Z-Score ─────────────────────
          Row(children: [
            Expanded(child: _MetricCard(
              label: 'Chronic (EWMA)',
              value: _last.chronic.toStringAsFixed(0),
              color: Colors.amberAccent,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: 'ACWR',
              value: _last.acwr <= 0 ? '—' : _last.acwr.toStringAsFixed(2),
              sub: _acwrLabel(acwr),
              color: acCol,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: 'Z-Score',
              value: _last.z.toStringAsFixed(2),
              sub: _last.z.abs() > 2 ? 'Flagged' : 'Normal',
              color: _last.z.abs() > 2 ? Colors.redAccent : Colors.tealAccent,
            )),
          ]),
          const SizedBox(height: 10),

          // ── Load Guidance (Target Range) ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _loadGuidanceColor(_last.load, tLow, tHigh).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _loadGuidanceColor(_last.load, tLow, tHigh).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.track_changes_rounded,
                    size: 16,
                    color: _loadGuidanceColor(_last.load, tLow, tHigh)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tomorrow\'s Load Target',
                          style: TextStyle(fontSize: 10, color: _kTxtS)),
                      const SizedBox(height: 2),
                      Text('Target: $tLow – $tHigh',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _loadGuidanceColor(_last.load, tLow, tHigh),
                          )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('80% – 130%',
                        style: const TextStyle(fontSize: 9, color: _kTxtS)),
                    Text('of Chronic ${_last.chronic.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 9, color: _kTxtS)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── ACWR Gauge ─────────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ACWR Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTxtP)),
                const SizedBox(height: 10),
                _AcwrGauge(acwr: acwr),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Load Chart ─────────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Load History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTxtP)),
                const SizedBox(height: 6),
                _legend(barColor, accentColor),
                const SizedBox(height: 10),
                SizedBox(
                  height: 200,
                  child: _ScrollableChart(data: data, barColor: barColor, accentColor: accentColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── ACWR Trend Line ────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ACWR Trend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTxtP)),
                const SizedBox(height: 4),
                Text('Dashed zone lines: Under(0.8) | Sweet(1.3) | Caution(1.5)',
                    style: const TextStyle(fontSize: 10, color: _kTxtS)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: _AcwrTrendChart(data: data, lineColor: accentColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Session Log ────────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Session Log (latest 10)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTxtP)),
                const SizedBox(height: 8),
                ...List.generate(
                  data.length.clamp(0, 10),
                  (i) {
                    final idx = data.length - 1 - i;
                    return _SessionRow(pt: data[idx], color: barColor);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _legend(Color bar, Color line) {
    return Wrap(spacing: 14, runSpacing: 4, children: [
      _legendDot(bar, 'Session Load'),
      _legendLine(Colors.lightBlueAccent, '7-day Acute'),
      _legendLine(Colors.amberAccent, 'Chronic EWMA'),
      _legendLine(Colors.pinkAccent, 'Exertion'),
    ]);
  }

  Widget _legendDot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 9, color: _kTxtS)),
  ]);

  Widget _legendLine(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 16, height: 2, color: c),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 9, color: _kTxtS)),
  ]);

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
    ),
    child: child,
  );
}

// ── Metric Card ───────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label, value;
  final String sub;
  final Color color;
  const _MetricCard({required this.label, required this.value, this.sub = '', required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _kTxtS)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 9, color: _kTxtS), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    ),
  );
}

// ── ACWR Gauge ────────────────────────────────────────────────────────────────

class _AcwrGauge extends StatelessWidget {
  final double acwr;
  const _AcwrGauge({required this.acwr});

  @override
  Widget build(BuildContext context) {
    final clamped = acwr.clamp(0.0, 2.0);
    Color zoneColor(double v) {
      if (v <= 0)   return Colors.grey;
      if (v < 0.8)  return Colors.blueAccent;
      if (v <= 1.3) return Colors.greenAccent;
      if (v <= 1.5) return Colors.orangeAccent;
      return Colors.redAccent;
    }
    final col = zoneColor(acwr);

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 16,
          child: Row(children: [
            Expanded(flex: 40,  child: Container(color: Colors.blueAccent.withValues(alpha: 0.7))),
            Expanded(flex: 50,  child: Container(color: Colors.greenAccent.withValues(alpha: 0.85))),
            Expanded(flex: 10,  child: Container(color: Colors.orangeAccent.withValues(alpha: 0.85))),
            Expanded(flex: 100, child: Container(color: Colors.redAccent.withValues(alpha: 0.7))),
          ]),
        ),
      ),
      const SizedBox(height: 3),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('0',    style: TextStyle(fontSize: 9, color: _kTxtS)),
          Text('0.8',  style: TextStyle(fontSize: 9, color: _kTxtS)),
          Text('1.3',  style: TextStyle(fontSize: 9, color: _kTxtS)),
          Text('1.5',  style: TextStyle(fontSize: 9, color: _kTxtS)),
          Text('2.0+', style: TextStyle(fontSize: 9, color: _kTxtS)),
        ],
      ),
      LayoutBuilder(builder: (ctx, c) {
        final x = (c.maxWidth * (clamped / 2.0)).clamp(0.0, c.maxWidth - 20.0);
        return Stack(children: [
          const SizedBox(height: 22),
          Positioned(
            left: x,
            child: Icon(Icons.arrow_drop_down, color: acwr <= 0 ? Colors.grey : Colors.white, size: 20),
          ),
        ]);
      }),
      const SizedBox(height: 2),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: col.withValues(alpha: 0.5)),
            ),
            child: Text(
              acwr <= 0 ? 'No sessions logged yet' : 'ACWR ${acwr.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: col, fontSize: 12),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: const [
        _ZL('Under\nTraining', Colors.blueAccent),
        _ZL('Sweet\nSpot ✓',   Colors.greenAccent),
        _ZL('Caution',        Colors.orangeAccent),
        _ZL('Danger\nZone',   Colors.redAccent),
      ]),
    ]);
  }
}

class _ZL extends StatelessWidget {
  final String t;
  final Color  c;
  const _ZL(this.t, this.c);
  @override
  Widget build(BuildContext ctx) =>
      Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: c));
}

// ── Scrollable Load Chart ─────────────────────────────────────────────────────

class _ScrollableChart extends StatelessWidget {
  final List<_LP> data;
  final Color barColor, accentColor;
  const _ScrollableChart({required this.data, required this.barColor, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    const slotW = 26.0;
    final chartW = max(slotW * data.length, MediaQuery.of(context).size.width - 56);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartW,
        child: CustomPaint(
          painter: _LoadChartPainter(data: data, barColor: barColor),
        ),
      ),
    );
  }
}

class _LoadChartPainter extends CustomPainter {
  final List<_LP> data;
  final Color barColor;
  _LoadChartPainter({required this.data, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const bPad = 24.0, tPad = 8.0;
    final chartH = size.height - bPad - tPad;
    final n      = data.length;
    final slotW  = size.width / n;
    double xAt(int i) => slotW * i + slotW / 2;

    // Compute scales (exclude extreme early-period values for training load)
    final loads   = data.map((d) => d.load).toList();
    final acutes  = data.map((d) => d.acute).toList();
    final chronics = data.map((d) => d.chronic).toList();
    final allVals = [...loads, ...acutes, ...chronics];
    final vMax = allVals.reduce(max).clamp(1.0, double.infinity);

    double yAt(double v) => tPad + chartH * (1.0 - v / vMax);

    // Grid lines
    final gridP = Paint()..color = Colors.white10..strokeWidth = 0.5;
    for (final frac in [0.25, 0.5, 0.75, 1.0]) {
      final y = tPad + chartH * (1 - frac);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridP);
      _txt(canvas, (vMax * frac).toStringAsFixed(0), 0, y - 6, Colors.white24, 7);
    }

    // Bars (session load)
    final barW = (slotW * 0.5).clamp(4.0, 18.0);
    for (int i = 0; i < n; i++) {
      final h = data[i].load > 0 ? (chartH * data[i].load / vMax).clamp(2.0, chartH) : 0.0;
      if (h <= 0) continue;
      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(xAt(i) - barW / 2, tPad + chartH - h, barW, h),
        topLeft: const Radius.circular(3), topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rRect, Paint()..color = barColor.withValues(alpha: 0.7));
    }

    // 7-day Acute line (lightBlue)
    _drawLine(canvas, n, xAt, yAt, data.map((d) => d.acute).toList(), Colors.lightBlueAccent, 2.0, dashed: false);
    // Chronic EWMA line (amber, dashed)
    _drawLine(canvas, n, xAt, yAt, data.map((d) => d.chronic).toList(), Colors.amberAccent, 1.5, dashed: true);
    // Exertion line (pink) — normalized from 0-10 scale to chart scale
    final exertionNorm = data.map((d) => d.load > 0 ? (log(d.load) / log(1000)) * 10.0 * vMax / 10.0 : 0.0).toList();
    _drawLine(canvas, n, xAt, yAt, exertionNorm, Colors.pinkAccent, 2.0, dashed: false);

    // Date labels (every 3 or 5 points)
    final step = n > 20 ? 4 : (n > 10 ? 3 : 2);
    for (int i = 0; i < n; i += step) {
      _txt(canvas, data[i].d, xAt(i), size.height - bPad + 4, _kTxtS, 7);
    }
    // Always show last date
    _txt(canvas, data[n - 1].d, xAt(n - 1), size.height - bPad + 4, _kTxtS, 7);
  }

  void _drawLine(Canvas canvas, int n, double Function(int) xAt, double Function(double) yAt,
      List<double> vals, Color color, double sw, {required bool dashed}) {
    if (n < 2) return;
    final paint = Paint()..color = color..strokeWidth = sw..style = PaintingStyle.stroke;
    final pts = List.generate(n, (i) => Offset(xAt(i), yAt(vals[i])));
    if (!dashed) {
      // Catmull-Rom smooth spline
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 0; i < n - 1; i++) {
        final p0 = i > 0 ? pts[i - 1] : pts[0];
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
        final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
        final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      }
      canvas.drawPath(path, paint);
      for (final p in pts) {
        canvas.drawCircle(p, 2.5, Paint()..color = color);
      }
    } else {
      // Smooth dashed line via Catmull-Rom
      for (int i = 0; i < n - 1; i++) {
        _dash(canvas, paint, pts[i], pts[i + 1]);
      }
    }
  }

  void _dash(Canvas c, Paint p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final nx = dx / dist, ny = dy / dist;
    double t = 0;
    while (t < dist) {
      final e = (t + 4.0).clamp(0.0, dist);
      c.drawLine(Offset(a.dx + nx * t, a.dy + ny * t), Offset(a.dx + nx * e, a.dy + ny * e), p);
      t += 7.0;
    }
  }

  void _txt(Canvas c, String s, double cx, double cy, Color col, double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _LoadChartPainter old) =>
      old.data != data || old.barColor != barColor;
}

// ── ACWR Trend Chart ──────────────────────────────────────────────────────────

class _AcwrTrendChart extends StatelessWidget {
  final List<_LP> data;
  final Color lineColor;
  const _AcwrTrendChart({required this.data, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    const slotW = 26.0;
    final chartW = max(slotW * data.length, MediaQuery.of(context).size.width - 56);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartW,
        child: CustomPaint(painter: _AcwrPainter(data: data, lineColor: lineColor)),
      ),
    );
  }
}

class _AcwrPainter extends CustomPainter {
  final List<_LP> data;
  final Color lineColor;
  _AcwrPainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const bPad = 24.0, tPad = 8.0;
    final chartH = size.height - bPad - tPad;
    final n = data.length;
    final slotW = size.width / n;
    double xAt(int i) => slotW * i + slotW / 2;

    const vMax = 2.5, vMin = 0.0;
    double yAt(double v) => tPad + chartH * (1.0 - (v - vMin) / (vMax - vMin));

    // Zone bands
    void band(double lo, double hi, Color c) {
      canvas.drawRect(
        Rect.fromLTRB(0, yAt(hi), size.width, yAt(lo)),
        Paint()..color = c.withValues(alpha: 0.06),
      );
    }
    band(0.0, 0.8, Colors.blueAccent);
    band(0.8, 1.3, Colors.greenAccent);
    band(1.3, 1.5, Colors.orangeAccent);
    band(1.5, 2.5, Colors.redAccent);

    // Zone boundary lines
    for (final thresh in [0.8, 1.3, 1.5]) {
      final y = yAt(thresh.toDouble());
      _dashH(canvas, size.width, y, Colors.white24);
      _txt(canvas, thresh.toStringAsFixed(1), 6, y - 8, Colors.white38, 7.5);
    }

    // ACWR clamped values
    final vals = data.map((d) => d.acwr.clamp(vMin, vMax)).toList();

    // Smooth color-coded ACWR line using Catmull-Rom spline per segment
    Color segColor(double v) {
      if (v < 0.8)  return Colors.blueAccent;
      if (v <= 1.3) return Colors.greenAccent;
      if (v <= 1.5) return Colors.orangeAccent;
      return Colors.redAccent;
    }
    final pts = List.generate(n, (i) => Offset(xAt(i), yAt(vals[i])));
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[0];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      final mid = (vals[i] + vals[i + 1]) / 2;
      canvas.drawPath(path, Paint()..color = segColor(mid)..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }

    // Dots
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(pts[i], 3.5, Paint()..color = segColor(vals[i]));
    }

    // Date labels
    final step = n > 20 ? 4 : (n > 10 ? 3 : 2);
    for (int i = 0; i < n; i += step) {
      _txt(canvas, data[i].d, xAt(i), size.height - bPad + 4, _kTxtS, 7);
    }
    _txt(canvas, data[n - 1].d, xAt(n - 1), size.height - bPad + 4, _kTxtS, 7);
  }

  void _dashH(Canvas c, double w, double y, Color col) {
    final p = Paint()..color = col..strokeWidth = 0.8;
    double x = 0;
    while (x < w) {
      c.drawLine(Offset(x, y), Offset(min(x + 5, w), y), p);
      x += 9;
    }
  }

  void _txt(Canvas c, String s, double cx, double cy, Color col, double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _AcwrPainter old) => old.data != data;
}

// ── Session Log Row ───────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final _LP pt;
  final Color color;
  const _SessionRow({required this.pt, required this.color});

  @override
  Widget build(BuildContext context) {
    Color acwrCol(double v) {
      if (v <= 0)   return Colors.grey;
      if (v < 0.8)  return Colors.blueAccent;
      if (v <= 1.3) return Colors.greenAccent;
      if (v <= 1.5) return Colors.orangeAccent;
      return Colors.redAccent;
    }
    final acCol = acwrCol(pt.acwr);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44, alignment: Alignment.center,
              child: Text(pt.d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kTxtS)),
            ),
            Container(width: 1, height: 28, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 10)),
            Expanded(
              child: Row(children: [
                _stat('Load', pt.load.toStringAsFixed(0), color),
                _stat('Acute', pt.acute.toStringAsFixed(0), Colors.lightBlueAccent),
                _stat('Chronic', pt.chronic.toStringAsFixed(0), Colors.amberAccent),
                _stat('ACWR', pt.acwr <= 0 ? '—' : pt.acwr.toStringAsFixed(2), acCol),
                _stat('Z', pt.z.toStringAsFixed(2),
                    pt.z.abs() > 2 ? Colors.redAccent : Colors.tealAccent),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color c) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: _kTxtS)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ],
    ),
  );
}

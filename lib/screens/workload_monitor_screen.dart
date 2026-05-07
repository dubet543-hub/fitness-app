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
  final double acute;   // 7-day rolling load
  final double chronic; // 28-day EWMA
  final double acwr;
  final double z;
  const _LP(this.d, this.load, this.acute, this.chronic, this.acwr, this.z);
}

// ── Static Dataset (PDF: Workload Monitoring – Cleaned Daily Data) ─────────────

// ─── Athlete 1 (ATS-2025-001) ─────────────────────────────────────────────────

const _a1Train = <_LP>[
  _LP('19/03',   0,   0,    0,   0.0,   0.00),
  _LP('21/03', 135, 135,    9,  14.5,  19.09),
  _LP('22/03',   0, 135,   18,   7.5,  13.02),
  _LP('23/03',   0, 135,   26,   5.2,   9.72),
  _LP('24/03',   0, 135,   34,   4.0,   7.64),
  _LP('25/03',   0, 135,   41,   3.3,   6.22),
  _LP('26/03',   0, 135,   47,   2.9,   5.19),
  _LP('27/03', 141, 138,   53,   2.6,   4.54),
  _LP('29/03',   0, 141,   59,   2.4,   4.03),
  _LP('31/03', 624, 383,   82,   4.7,  12.16),
  _LP('01/04',   0, 383,  102,   3.7,   9.13),
  _LP('02/04',   0, 383,  122,   3.1,   7.03),
  _LP('03/04',   0, 383,  140,   2.7,   5.59),
  _LP('04/04',   0, 624,  173,   3.6,   8.65),
  _LP('05/04',   0, 624,  204,   3.1,   6.79),
  _LP('06/04',   0, 624,  233,   2.7,   5.45),
  _LP('07/04', 205, 415,  246,   1.7,   2.12),
  _LP('08/04', 215, 210,  243,   0.9,  -0.39),
  _LP('09/04', 116, 179,  239,   0.7,  -0.68),
  _LP('10/04',   0, 179,  235,   0.8,  -0.62),
  _LP('11/04', 747, 321,  241,   1.3,   0.87),
  _LP('12/04', 155, 288,  244,   1.2,   0.47),
  _LP('13/04', 236, 279,  246,   1.1,   0.34),
  _LP('14/04',   0, 279,  248,   1.1,   0.32),
  _LP('15/04',   0, 294,  252,   1.2,   0.44),
  _LP('16/04', 392, 383,  261,   1.5,   1.29),
  _LP('17/04',   0, 383,  269,   1.4,   1.19),
  _LP('18/04',   0, 261,  268,   1.0,  -0.08),
  _LP('19/04',   0, 314,  272,   1.2,   0.45),
  _LP('20/04',   0, 392,  280,   1.4,   1.29),
  _LP('21/04',   0, 392,  288,   1.4,   1.19),
  _LP('22/04', 270, 331,  291,   1.1,   0.51),
  _LP('23/04', 192, 285,  290,   1.0,  -0.07),
  _LP('24/04', 172, 211,  285,   0.7,  -1.00),
  _LP('25/04', 135, 192,  278,   0.7,  -1.29),
  _LP('26/04', 329, 220,  274,   0.8,  -0.93),
  _LP('27/04',   0, 220,  271,   0.8,  -0.88),
  _LP('28/04',   0, 220,  267,   0.8,  -0.83),
  _LP('29/04',   0, 220,  264,   0.8,  -1.05),
  _LP('30/04',   0, 212,  260,   0.8,  -1.17),
  _LP('01/05', 178, 214,  257,   0.8,  -1.65),
  _LP('02/05', 603, 370,  265,   1.4,   5.18),
  _LP('03/05',   0, 370,  272,   1.4,   5.68),
];

const _a1Skill = <_LP>[
  _LP('19/03', 560, 560, 560,  1.0,  0.00),
  _LP('21/03',   0, 560, 560,  1.0,  0.00),
  _LP('22/03',   0, 560, 560,  1.0,  0.00),
  _LP('23/03',   0, 560, 560,  1.0,  0.00),
  _LP('24/03',  54, 307, 543,  0.6, -2.10),
  _LP('25/03', 288, 301, 526,  0.6, -1.70),
  _LP('26/03',  72, 138, 499,  0.3, -2.10),
  _LP('27/03',   0, 138, 474,  0.3, -1.80),
  _LP('29/03', 288, 176, 454,  0.4, -1.40),
  _LP('31/03',   0, 216, 437,  0.5, -1.20),
  _LP('01/04', 294, 218, 422,  0.5, -1.10),
  _LP('02/04',   0, 291, 413,  0.7, -0.70),
  _LP('03/04', 450, 344, 408,  0.8, -0.40),
  _LP('04/04',   0, 344, 404,  0.9, -0.40),
  _LP('05/04',   0, 344, 400,  0.9, -0.40),
  _LP('06/04', 135, 293, 392,  0.7, -0.70),
  _LP('07/04', 228, 277, 384,  0.7, -0.70),
  _LP('08/04',  36, 212, 373,  0.6, -1.10),
  _LP('09/04',  36, 177, 359,  0.5, -1.30),
  _LP('10/04', 180, 123, 343,  0.4, -1.50),
  _LP('11/04',   0, 123, 328,  0.4, -1.40),
  _LP('12/04',  84, 117, 313,  0.4, -1.30),
  _LP('13/04', 112, 113, 299,  0.4, -1.20),
  _LP('14/04', 270, 135, 288,  0.5, -1.00),
  _LP('15/04',  96, 116, 276,  0.4, -1.10),
  _LP('16/04', 310, 175, 269,  0.7, -0.70),
  _LP('17/04', 160, 172, 262,  0.7, -0.70),
  _LP('18/04', 160, 170, 256,  0.7, -0.60),
  _LP('19/04',  90, 171, 250,  0.7, -0.60),
  _LP('20/04',  36, 160, 244,  0.7, -1.10),
  _LP('21/04',   0, 142, 237,  0.6, -1.20),
  _LP('22/04',   0, 151, 231,  0.7, -1.10),
  _LP('23/04',   0, 151, 226,  0.7, -1.00),
  _LP('24/04',   0, 112, 218,  0.5, -1.40),
  _LP('25/04', 120, 102, 210,  0.5, -1.40),
  _LP('26/04',   0,  82, 201,  0.4, -1.50),
  _LP('27/04',  72,  76, 192,  0.4, -1.40),
  _LP('28/04', 126, 106, 186,  0.6, -1.00),
  _LP('29/04',  80, 100, 180,  0.6, -1.00),
  _LP('30/04', 135, 107, 175,  0.6, -0.80),
  _LP('01/05',   0, 107, 171,  0.6, -0.90),
  _LP('02/05',   0, 103, 166,  0.6, -1.00),
  _LP('03/05',   0, 103, 162,  0.6, -1.10),
];

const _a1Total = <_LP>[
  _LP('19/03', 560, 560, 560, 1.0,  0.00),
  _LP('21/03', 135, 348, 545, 0.6, -0.66),
  _LP('22/03',   0, 348, 532, 0.7, -0.61),
  _LP('23/03',   0, 348, 519, 0.7, -0.57),
  _LP('24/03',  54, 250, 500, 0.5, -0.92),
  _LP('25/03', 288, 259, 484, 0.5, -1.01),
  _LP('26/03',  72, 137, 460, 0.3, -1.53),
  _LP('27/03', 141, 138, 438, 0.3, -1.57),
  _LP('29/03', 288, 169, 419, 0.4, -1.42),
  _LP('31/03', 624, 283, 410, 0.7, -0.58),
  _LP('01/04', 294, 284, 401, 0.7, -0.58),
  _LP('02/04',   0, 337, 397, 0.8, -0.29),
  _LP('03/04', 450, 359, 394, 0.9, -0.17),
  _LP('04/04',   0, 414, 395, 1.0,  0.09),
  _LP('05/04',   0, 414, 397, 1.0,  0.09),
  _LP('06/04', 135, 376, 395, 1.0, -0.10),
  _LP('07/04', 433, 387, 395, 1.0, -0.04),
  _LP('08/04', 251, 317, 389, 0.8, -0.39),
  _LP('09/04', 152, 284, 382, 0.7, -0.54),
  _LP('10/04', 180, 230, 372, 0.6, -0.81),
  _LP('11/04', 747, 316, 368, 0.9, -0.25),
  _LP('12/04', 239, 305, 363, 0.8, -0.29),
  _LP('13/04', 348, 336, 362, 0.9, -0.13),
  _LP('14/04', 270, 328, 359, 0.9, -0.17),
  _LP('15/04',  96, 285, 354, 0.8, -0.36),
  _LP('16/04', 702, 369, 355, 1.0,  0.07),
  _LP('17/04', 160, 366, 356, 1.0,  0.05),
  _LP('18/04', 160, 282, 351, 0.8, -0.35),
  _LP('19/04',  90, 261, 345, 0.8, -0.42),
  _LP('20/04',  36, 216, 336, 0.6, -0.59),
  _LP('21/04',   0, 207, 327, 0.6, -0.59),
  _LP('22/04', 270, 236, 321, 0.7, -0.42),
  _LP('23/04', 192, 230, 314, 0.7, -0.43),
  _LP('24/04', 172, 154, 303, 0.5, -0.77),
  _LP('25/04', 255, 168, 294, 0.6, -0.66),
  _LP('26/04', 329, 192, 287, 0.7, -0.50),
  _LP('27/04',  72, 189, 280, 0.7, -0.47),
  _LP('28/04', 126, 202, 275, 0.7, -0.38),
  _LP('29/04',  80, 187, 269, 0.7, -0.45),
  _LP('30/04', 135, 167, 262, 0.6, -0.53),
  _LP('01/05', 178, 168, 255, 0.7, -0.50),
  _LP('02/05', 603, 218, 253, 0.9, -0.19),
  _LP('03/05',   0, 218, 250, 0.9, -0.18),
];

// ─── Athlete 2 (ATS-2025-002) ─────────────────────────────────────────────────

const _a2Train = <_LP>[
  _LP('21/03', 990, 990, 990, 1.0,  0.00),
  _LP('22/03',   0, 990, 990, 1.0,  0.00),
  _LP('23/03', 100, 545, 959, 0.6, -23.38),
  _LP('24/03',  96, 395, 920, 0.4, -15.90),
  _LP('25/03',   0, 395, 884, 0.4, -10.62),
  _LP('26/03', 390, 394, 850, 0.5,  -7.93),
  _LP('27/03', 448, 405, 820, 0.5,  -6.13),
  _LP('28/03', 150, 362, 788, 0.5,  -5.51),
  _LP('29/03',   0, 237, 750, 0.3,  -5.84),
  _LP('30/03', 540, 287, 718, 0.4,  -4.40),
  _LP('31/03', 170, 340, 692, 0.5,  -3.30),
  _LP('01/04',  96, 299, 665, 0.4,  -3.18),
  _LP('02/04',   0, 299, 640, 0.5,  -2.77),
  _LP('03/04',   0, 239, 612, 0.4,  -2.86),
  _LP('04/04',   0, 269, 588, 0.5,  -2.32),
  _LP('05/04',   0, 269, 566, 0.5,  -2.06),
  _LP('06/04', 458, 241, 544, 0.4,  -2.01),
  _LP('07/04', 588, 381, 533, 0.7,  -0.97),
  _LP('08/04', 385, 382, 522, 0.7,  -0.88),
  _LP('09/04', 510, 485, 520, 0.9,  -0.21),
  _LP('10/04',  80, 404, 512, 0.8,  -0.65),
  _LP('11/04', 480, 417, 505, 0.8,  -0.52),
  _LP('12/04',   0, 417, 499, 0.8,  -0.48),
  _LP('13/04', 540, 434, 495, 0.9,  -0.35),
  _LP('14/04', 445, 433, 490, 0.9,  -0.33),
  _LP('15/04', 600, 434, 487, 0.9,  -0.30),
  _LP('16/04', 335, 413, 481, 0.9,  -0.39),
  _LP('17/04', 105, 369, 474, 0.8,  -0.60),
  _LP('18/04', 390, 403, 469, 0.9,  -0.40),
  _LP('20/04', 371, 398, 464, 0.9,  -0.43),
  _LP('21/04', 186, 331, 455, 0.7,  -0.94),
  _LP('22/04', 240, 271, 442, 0.6,  -1.42),
  _LP('23/04', 301, 275, 431, 0.6,  -1.28),
  _LP('24/04', 320, 301, 422, 0.7,  -1.19),
  _LP('25/04',   0, 301, 413, 0.7,  -1.09),
  _LP('26/04',   0, 284, 404, 0.7,  -1.29),
  _LP('27/04', 178, 245, 393, 0.6,  -1.90),
  _LP('28/04',   0, 245, 383, 0.6,  -1.72),
  _LP('29/04', 245, 257, 374, 0.7,  -1.57),
  _LP('30/04', 258, 260, 367, 0.7,  -1.65),
  _LP('01/05', 300, 245, 358, 0.7,  -1.69),
  _LP('02/05', 229, 242, 350, 0.7,  -1.67),
  _LP('03/05',   0, 242, 343, 0.7,  -1.58),
];

const _a2Skill = <_LP>[
  _LP('19/03', 560, 560, 560, 1.0,  0.00),
  _LP('21/03',   0,   0,   0, 0.0,  0.00),
  _LP('22/03',   0,   0,   0, 0.0,  0.00),
  _LP('24/03', 216, 108,   7,14.5,  1.90),
  _LP('25/03', 525, 247,  24,10.3,  2.00),
  _LP('26/03',   0, 247,  39, 6.3,  1.70),
  _LP('27/03',   0, 247,  54, 4.6,  1.60),
  _LP('28/03', 144, 221,  65, 3.4,  1.30),
  _LP('29/03', 504, 347,  85, 4.1,  2.00),
  _LP('30/03',   0, 347, 103, 3.4,  1.80),
  _LP('31/03',   0, 391, 123, 3.2,  1.80),
  _LP('01/04',   0, 324, 137, 2.4,  1.30),
  _LP('02/04',   0, 324, 149, 2.2,  1.20),
  _LP('03/04',   0, 324, 162, 2.0,  1.20),
  _LP('04/04',   0, 504, 185, 2.7,  2.10),
  _LP('05/04',   0, 172, 191, 0.9, -1.10),
  _LP('06/04',   0, 160, 179, 0.9, -1.00),
  _LP('07/04', 300, 300, 170, 1.8,  0.90),
  _LP('08/04', 280, 290, 178, 1.6,  0.80),
  _LP('09/04', 100, 227, 182, 1.2,  0.30),
  _LP('10/04', 270, 238, 186, 1.3,  0.40),
  _LP('11/04',   0, 238, 189, 1.3,  0.40),
  _LP('12/04',   0, 238, 192, 1.2,  0.30),
  _LP('13/04', 300, 250, 196, 1.3,  0.40),
  _LP('14/04', 360, 268, 201, 1.3,  0.50),
  _LP('15/04', 360, 278, 207, 1.3,  0.60),
  _LP('16/04', 280, 314, 214, 1.5,  0.80),
  _LP('17/04', 240, 302, 220, 1.4,  0.70),
  _LP('18/04',   0, 308, 226, 1.4,  0.80),
  _LP('20/04', 150, 282, 230, 1.2,  0.60),
  _LP('21/04',  30, 212, 229, 0.9, -0.30),
  _LP('22/04',  45, 149, 223, 0.7, -1.10),
  _LP('23/04',  80, 138, 217, 0.6, -1.10),
  _LP('24/04', 150,  91, 209, 0.4, -1.40),
  _LP('25/04', 120,  96, 201, 0.5, -1.20),
  _LP('26/04', 180, 108, 194, 0.6, -0.90),
  _LP('27/04',  12,  88, 187, 0.5, -1.00),
  _LP('28/04',   0,  88, 180, 0.5, -0.90),
  _LP('29/04',   0,  98, 175, 0.6, -0.80),
  _LP('30/04', 180, 120, 171, 0.7, -0.50),
  _LP('01/05', 175, 133, 168, 0.8, -0.30),
  _LP('02/05', 100, 129, 166, 0.8, -0.40),
  _LP('03/05',   0, 129, 163, 0.8, -0.40),
];

const _a2Total = <_LP>[
  _LP('19/03', 560, 560, 560, 1.0,  0.00),
  _LP('21/03', 990, 990, 990, 1.0,  0.00),
  _LP('22/03',   0, 990, 990, 1.0,  0.00),
  _LP('23/03', 100, 545, 959, 0.6, -0.66),
  _LP('24/03', 312, 467, 925, 0.5, -0.99),
  _LP('25/03', 525, 482, 895, 0.5, -1.09),
  _LP('26/03', 390, 463, 865, 0.5, -1.21),
  _LP('27/03', 448, 461, 837, 0.6, -1.27),
  _LP('28/03', 294, 437, 810, 0.5, -1.34),
  _LP('29/03', 504, 368, 779, 0.5, -1.59),
  _LP('30/03', 540, 389, 752, 0.5, -1.49),
  _LP('31/03', 170, 410, 729, 0.6, -1.29),
  _LP('01/04',  96, 349, 702, 0.5, -1.39),
  _LP('02/04',   0, 349, 678, 0.5, -1.29),
  _LP('03/04',   0, 321, 653, 0.5, -1.30),
  _LP('04/04',   0, 328, 631, 0.5, -1.19),
  _LP('05/04',   0, 269, 606, 0.4, -1.32),
  _LP('06/04', 458, 241, 581, 0.4, -1.39),
  _LP('07/04', 888, 481, 574, 0.8, -0.35),
  _LP('08/04', 665, 527, 571, 0.9, -0.17),
  _LP('09/04', 610, 655, 576, 1.1,  0.30),
  _LP('10/04', 350, 594, 578, 1.0,  0.07),
  _LP('11/04', 480, 575, 578, 1.0, -0.01),
  _LP('12/04',   0, 575, 577, 1.0, -0.01),
  _LP('13/04', 840, 613, 580, 1.1,  0.13),
  _LP('14/04', 805, 663, 586, 1.1,  0.30),
  _LP('15/04', 960, 673, 592, 1.1,  0.30),
  _LP('16/04', 615, 675, 597, 1.1,  0.29),
  _LP('17/04', 345, 628, 599, 1.0,  0.11),
  _LP('18/04', 390, 659, 604, 1.1,  0.23),
  _LP('20/04', 521, 639, 606, 1.1,  0.14),
  _LP('21/04', 216, 508, 599, 0.8, -0.40),
  _LP('22/04', 285, 395, 585, 0.7, -0.81),
  _LP('23/04', 381, 393, 572, 0.7, -0.78),
  _LP('24/04', 470, 377, 559, 0.7, -0.78),
  _LP('25/04', 120, 340, 543, 0.6, -0.84),
  _LP('26/04', 180, 310, 527, 0.6, -0.88),
  _LP('27/04', 190, 263, 509, 0.5, -0.95),
  _LP('28/04',   0, 263, 492, 0.5, -0.89),
  _LP('29/04', 245, 267, 477, 0.6, -0.82),
  _LP('30/04', 438, 289, 464, 0.6, -0.72),
  _LP('01/05', 475, 275, 451, 0.6, -0.75),
  _LP('02/05', 329, 310, 441, 0.7, -0.57),
  _LP('03/05',   0, 310, 432, 0.7, -0.53),
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
  late final TabController _tabs;

  List<_LP> get _train  => _athlete == 0 ? _a1Train  : _a2Train;
  List<_LP> get _skill  => _athlete == 0 ? _a1Skill  : _a2Skill;
  List<_LP> get _total  => _athlete == 0 ? _a1Total  : _a2Total;

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
      body: TabBarView(
        controller: _tabs,
        children: [
          _SectionView(
            data:       _train,
            accentColor: Colors.lightBlueAccent,
            sectionTitle: 'Training Session Exertion',
            barColor:   Colors.lightBlueAccent,
          ),
          _SectionView(
            data:       _skill,
            accentColor: Colors.greenAccent,
            sectionTitle: 'Skill Session Exertion',
            barColor:   Colors.greenAccent,
          ),
          _SectionView(
            data:       _total,
            accentColor: Colors.purpleAccent,
            sectionTitle: 'Daily Total Load & Exertion',
            barColor:   Colors.purpleAccent,
          ),
        ],
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
    if (v <= 1.3) return 'Sweet Spot ✓';
    if (v <= 1.5) return 'Caution';
    return 'Danger Zone';
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: _kTxtS)));
    }
    final acwr  = _last.acwr;
    final acCol = _acwrColor(acwr);

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

          // ── Key Metrics ────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _MetricCard(
              label: 'Session Load',
              value: _last.load.toStringAsFixed(0),
              sub: 'Latest',
              color: accentColor,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: '7-day Acute',
              value: _last.acute.toStringAsFixed(0),
              sub: 'Rolling sum',
              color: Colors.lightBlueAccent,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: 'Chronic (EWMA)',
              value: _last.chronic.toStringAsFixed(0),
              sub: '28-day',
              color: Colors.amberAccent,
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
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
              sub: _last.z.abs() > 2 ? 'Flag !' : 'Normal',
              color: _last.z.abs() > 2 ? Colors.redAccent : Colors.tealAccent,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: 'Data Points',
              value: data.length.toString(),
              sub: 'Sessions logged',
              color: _kTxtS,
            )),
          ]),
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
    return Row(children: [
      _legendDot(bar, 'Session Load (bars)'),
      const SizedBox(width: 14),
      _legendLine(Colors.lightBlueAccent, '7-day Acute'),
      const SizedBox(width: 14),
      _legendLine(Colors.amberAccent, 'Chronic EWMA'),
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
  final String label, value, sub;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.sub, required this.color});

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
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 9, color: _kTxtS), maxLines: 1, overflow: TextOverflow.ellipsis),
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
    final paint = Paint()..color = color..strokeWidth = sw..style = PaintingStyle.stroke;
    if (!dashed) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final p = Offset(xAt(i), yAt(vals[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
      for (int i = 0; i < n; i++) {
        canvas.drawCircle(Offset(xAt(i), yAt(vals[i])), 2.5, Paint()..color = color);
      }
    } else {
      for (int i = 0; i < n - 1; i++) {
        _dash(canvas, paint, Offset(xAt(i), yAt(vals[i])), Offset(xAt(i + 1), yAt(vals[i + 1])));
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

    // Color-coded segments
    for (int i = 0; i < n - 1; i++) {
      Color segColor(double v) {
        if (v < 0.8)  return Colors.blueAccent;
        if (v <= 1.3) return Colors.greenAccent;
        if (v <= 1.5) return Colors.orangeAccent;
        return Colors.redAccent;
      }
      final mid = (vals[i] + vals[i + 1]) / 2;
      canvas.drawLine(
        Offset(xAt(i), yAt(vals[i])),
        Offset(xAt(i + 1), yAt(vals[i + 1])),
        Paint()..color = segColor(mid)..strokeWidth = 2.5..strokeCap = StrokeCap.round,
      );
    }

    // Dots + values
    for (int i = 0; i < n; i++) {
      final v = vals[i];
      Color dotColor(double vv) {
        if (vv < 0.8)  return Colors.blueAccent;
        if (vv <= 1.3) return Colors.greenAccent;
        if (vv <= 1.5) return Colors.orangeAccent;
        return Colors.redAccent;
      }
      canvas.drawCircle(
        Offset(xAt(i), yAt(v)),
        3.5,
        Paint()..color = dotColor(v),
      );
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

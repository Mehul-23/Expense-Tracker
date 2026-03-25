import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

enum ChartStyle { pie, doughnut, bar, polar }

class CategoryChartWidget extends StatelessWidget {
  final Map<String, double> data;
  final ChartStyle chartStyle;
  final ValueChanged<ChartStyle> onChartStyleChanged;

  const CategoryChartWidget({
    super.key,
    required this.data,
    required this.chartStyle,
    required this.onChartStyleChanged,
  });

  List<Color> _colorsForCount(int count) {
    final base = [
      Colors.teal.shade600,
      Colors.green.shade600,
      Colors.blue.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.indigo.shade600,
      Colors.brown.shade600,
    ];
    return List.generate(count, (i) => base[i % base.length]);
  }

  List<PieChartSectionData> _buildSections(double total) {
    final colors = _colorsForCount(data.length);
    final entries = data.entries.toList();
    return List.generate(entries.length, (i) {
      final e = entries[i];
      final value = e.value;
      final percent = total > 0 ? value / total * 100 : 0.0;
      return PieChartSectionData(
        color: colors[i],
        value: value,
        title: '${percent.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      );
    });
  }

  Widget _buildChart(double total) {
    switch (chartStyle) {
      case ChartStyle.pie:
        return PieChart(PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 36,
          sections: _buildSections(total),
        ));
      case ChartStyle.doughnut:
        return PieChart(PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 70,
          sections: _buildSections(total),
        ));
      case ChartStyle.bar:
        final maxVal = data.values.fold(0.0, (a, b) => a > b ? a : b);
        return BarChart(BarChartData(
          maxY: maxVal * 1.2,
          barGroups: List.generate(data.length, (i) {
            final value = data.values.elementAt(i);
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: value,
                color: _colorsForCount(data.length)[i],
                width: 20,
                borderRadius: BorderRadius.circular(4),
              )
            ]);
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox();
                  return Text(
                    '₹${value.toInt()}',
                    style: const TextStyle(fontSize: 11),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final label = data.keys.elementAt(idx);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Transform.rotate(
                      angle: -0.6,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          minY: 0,
        ));
      case ChartStyle.polar:
        // Simulate a polar/radar chart using a pie chart with no center space
        return PieChart(PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 0,
          sections: _buildSections(total),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0.0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: chartStyle == ChartStyle.bar ? 1.0 : 1.3,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildChart(total),
            ),
          ),
        ),
      ],
    );
  }
}

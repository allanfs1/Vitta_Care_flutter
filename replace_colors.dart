import 'dart:io';

void main() {
  final dir = Directory('lib/features/ia');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final f in files) {
    String c = f.readAsStringSync();
    if (!c.contains('AppColors.')) continue;
    
    c = c.replaceAll('AppColors.backgroundDark', 'Theme.of(context).scaffoldBackgroundColor');
    c = c.replaceAll('AppColors.surfaceDark', 'Theme.of(context).colorScheme.surface');
    c = c.replaceAll('AppColors.borderDark', 'Theme.of(context).dividerColor');
    c = c.replaceAll('AppColors.textPrimaryDark', 'Theme.of(context).colorScheme.onSurface');
    c = c.replaceAll('AppColors.textSecondaryDark', 'Theme.of(context).colorScheme.onSurfaceVariant');
    c = c.replaceAll('AppColors.surfaceAltDark', 'Theme.of(context).colorScheme.surfaceContainerHighest');
    
    f.writeAsStringSync(c);
  }
}

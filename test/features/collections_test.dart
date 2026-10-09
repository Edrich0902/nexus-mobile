import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/features/kitchen/recipe_screen.dart';
import 'package:nexus_mobile/features/library/library_helpers.dart';

void main() {
  test('PageQuery is value-equal and drops empty filters', () {
    final a = PageQuery('/cellar/wines', const {'q': 'rioja', 'favourite': false, 'status': ''});
    final b = PageQuery('/cellar/wines', const {'q': 'rioja'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.params, {'q': 'rioja'});
    expect(PageQuery('/beer/beers'), isNot(PageQuery('/cellar/wines')));
  });

  test('recipeSteps splits on line breaks, step labels and sentences', () {
    expect(recipeSteps('STEP 1\nChop the onions.\nSTEP 2\nFry them gently.'), [
      'Chop the onions.',
      'Fry them gently.',
    ]);
    expect(recipeSteps('1. Boil water\n2) Add pasta'), ['Boil water', 'Add pasta']);
    expect(recipeSteps('Preheat the oven to 200C. Roast the vegetables until golden.'), [
      'Preheat the oven to 200C.',
      'Roast the vegetables until golden.',
    ]);
    expect(recipeSteps(null), isEmpty);
  });

  test('book helpers', () {
    expect(splitBookTitle('Dune: Messiah'), ('Dune:', 'Messiah'));
    expect(splitBookTitle('Dune'), ('Dune', null));
    expect(bookStatusLabel('want'), isNotEmpty);
    expect(parseDay('2026-03-04')?.day, 4);
  });
}

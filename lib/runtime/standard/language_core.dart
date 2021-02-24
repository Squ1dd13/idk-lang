library standard;

import 'package:language/runtime/exception.dart';
import 'package:language/runtime/primitive.dart';

import '../concrete.dart';
import '../expression.dart';
import '../function.dart';
import '../store.dart';
import '../type.dart';

void registerCore() {
  var printFunction = FunctionValue('print', NullType(), <Statement>[
    Statement(InlineExpression(() {
      var argument = Store.current().get('value').value;
      print(argument);

      return null;
    }))
  ])
    ..addParameter('value', AnyType())
    ..applyType();

  var fatalError = FunctionValue('fatal', NullType(), <Statement>[
    Statement(InlineExpression(() {
      var argument = Store.current().get('message').value;
      throw RuntimeError(argument.toString());
    }))
  ])
    ..addParameter('message', AnyType())
    ..applyType();

  Store.current().add('print', printFunction.createConstant());
  Store.current().add('fatal', fatalError.createConstant());

  Store.current().add('int', PrimitiveType.integer.createConstant());
  Store.current().add('String', PrimitiveType.string.createConstant());
  Store.current().add('proc', NullType().createConstant());
  Store.current().add('Any', AnyType().createConstant());
  Store.current().add('Type', TypeOfType.shared.createConstant());
  Store.current().add('null', NullType(name: 'null').createConstant());
}

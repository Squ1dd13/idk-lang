import '../lexer.dart';
import '../parser.dart';
import '../runtime/abstract.dart';
import '../runtime/concrete.dart';
import '../runtime/expression.dart';
import '../runtime/function.dart';
import '../runtime/store.dart';
import 'util.dart';

/// THIS IS NOT PERMANENT! Function call syntax will eventually be
/// handled as an operator (the '()' operator, like in C++). This class
/// exists only until we have an adequate enough operator system to
/// be able to do that.
class FunctionCall implements Statable, Expressible {
  String _calledName;
  final _arguments = <Expression>[];

  /// Constructs a [FunctionCall] but expects a semicolon at the end.
  /// This must be a separate constructor because the semicolon must
  /// be handled at parse-time and not evaluation-time.
  factory FunctionCall.statement(TokenStream tokens) {
    var created = FunctionCall(tokens);

    // Statement, so we need a semicolon.
    tokens.consumeSemicolon(5);
    return created;
  }

  FunctionCall(TokenStream tokens) {
    tokens.requireNext(
        'Function call must begin with the name of the function.',
        1,
        TokenPattern.type(TokenType.Name));

    _calledName = tokens.take().toString();

    tokens.requireNext(
        'Expected parenthesised argument list after function name in call.',
        2,
        GroupPattern('(', ')'));

    var argumentGroup = tokens.take() as GroupToken;
    var argumentSegments = Parse.split(argumentGroup.contents(),
        TokenPattern(string: ',', type: TokenType.Symbol));

    for (var segment in argumentSegments) {
      _arguments.add(Parse.expression(segment));
    }
  }

  @override
  Expression createExpression() {
    return InlineExpression(() {
      // Find something to call, then call it.
      var resolvedValue = Store.current().get(_calledName).get();

      if (!(resolvedValue is FunctionValue)) {
        throw Exception('Cannot call non-function $_calledName!');
      }

      var functionValue = resolvedValue as FunctionValue;
      var parameters = functionValue.parameters;

      if (_arguments.length != parameters.length) {
        throw Exception(
            'Incorrect number of arguments in call to function $_calledName! '
            '(Expected ${parameters.length}, got ${_arguments.length}.)');
      }

      // Map the arguments to their names.
      var mappedArguments = <String, Value>{};
      var parameterNames = parameters.keys.toList();

      for (var i = 0; i < _arguments.length; ++i) {
        mappedArguments[parameterNames[i]] = _arguments[i].evaluate();
      }

      return functionValue.call(mappedArguments);
    });
  }

  @override
  Statement createStatement() {
    return Statement(createExpression());
  }
}
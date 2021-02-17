import '../lexer.dart';
import '../runtime/concrete.dart';
import '../runtime/expression.dart';
import '../runtime/store.dart';
import 'assignment.dart';
import 'call.dart';
import 'conditional.dart';
import 'declaration.dart';
import 'function.dart';
import 'operation.dart';
import 'reference.dart';
import 'util.dart';

class Parse {
  static final _statementPasses = <Statement Function(TokenStream)>[
    (stream) => ConditionalClause(stream).createStatement(),
    (stream) => VariableDeclaration(stream).createStatement(),
    (stream) => Direction(stream).createStatement(),
    (stream) => Direction.redirection(stream).createStatement(),
    (stream) => FunctionDeclaration(stream).createStatement(),
    (stream) => FunctionCall.statement(stream).createStatement(),
    (stream) => Assignment(stream).createStatement(),
  ];

  static final _expressionPasses = <Expression Function(TokenStream)>[
    (stream) => FunctionCall(stream).createExpression(),
    (stream) => OperatorExpression(stream),
    (stream) => InlineDirection(stream).createExpression(),
  ];

  static List<ElementType> _parseRepeated<ElementType>(List<Token> tokens,
      Iterable<ElementType Function(TokenStream)> generators) {
    var stream = TokenStream(tokens, 0);
    var created = <ElementType>[];

    while (stream.hasCurrent()) {
      // We keep the exception thrown at the furthest point in parsing so
      //  that if nothing succeeds, we know what to complain about.
      var furthestException = InvalidSyntaxException('', -1, -1, -1);

      for (var pass in generators) {
        // Save the index in case this pass fails.
        stream.saveIndex();

        try {
          var parsed = pass(stream);
          created.add(parsed);

          // Invalidate the exception so it gets ignored.
          furthestException = InvalidSyntaxException('', -1, -1, -1);

          // This pass succeeded, so we can move on now.
          break;
        } on InvalidSyntaxException catch (exception) {
          // Pass failed, so restore the index so we can try again.
          stream.restoreIndex();

          if (exception.stage > furthestException.stage) {
            furthestException = exception;
          }
        }
      }

      if (furthestException.stage >= 0) {
        throw furthestException;
      }
    }

    return created;
  }

  static List<Statement> statements(List<Token> tokens) {
    return _parseRepeated(tokens, _statementPasses);
  }

  static List<List<Token>> split(TokenStream tokens, TokenPattern pattern) {
    var segments = <List<Token>>[];

    while (tokens.hasCurrent()) {
      // Collect tokens until we find a non-match.
      var taken = tokens.takeWhile(pattern.notMatch);

      if (taken.isNotEmpty) {
        segments.add(taken);
      } else {
        tokens.skip();
      }
    }

    return segments;
  }

  static Expression expression(List<Token> tokens) {
    if (tokens.length == 1) {
      if (tokens.first.type == TokenType.String) {
        return InlineExpression(() => StringValue(tokens.first.toString()));
      }

      if (tokens.first.type == TokenType.Number) {
        return InlineExpression(() => IntegerValue(tokens.first.toString()));
      }

      if (tokens.first.type == TokenType.Name) {
        return InlineExpression(() {
          return Store.current().get(tokens.first.toString());
        });
      }
    }

    var allParsed = _parseRepeated(tokens, _expressionPasses);

    if (allParsed.isEmpty) {
      return InlineExpression(() {
        print('Unparsed!');
        return null;
      });
    }

    if (allParsed.length > 1) {
      return InlineExpression(() {
        print('Too many results!');
        return null;
      });
    }

    return allParsed[0];
  }
}
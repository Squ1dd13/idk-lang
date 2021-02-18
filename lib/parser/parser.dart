import 'package:language/lexer.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/exception.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/store.dart';

import 'assignment.dart';
import 'call.dart';
import 'conditional.dart';
import 'declaration.dart';
import 'flow.dart';
import 'function.dart';
import 'iteration.dart';
import 'operation.dart';
import 'reference.dart';
import 'util.dart';

class Parse {
  static final _statementPasses = <Statement Function(TokenStream)>[
    (stream) => ConditionalClause(stream).createStatement(),
    (stream) => Loop(stream).createStatement(),
    (stream) => VariableDeclaration(stream).createStatement(),
    (stream) => Direction(stream).createStatement(),
    (stream) => Direction.redirection(stream).createStatement(),
    (stream) => FunctionDeclaration(stream).createStatement(),
    (stream) => FunctionCall.statement(stream).createStatement(),
    (stream) => Assignment(stream).createStatement(),
    (stream) => FlowStatement(stream).createStatement(),
    (stream) {
      var statement = Statement(OperatorExpression(stream));
      stream.consumeSemicolon(3);
      return statement;
    },
  ];

  static final _expressionPasses = <Expression Function(TokenStream)>[
    (stream) => FunctionCall(stream).createExpression(),
    (stream) => OperatorExpression(stream),
    (stream) => InlineDirection(stream).createExpression(),
  ];

  static List<ElementType> _parseRepeated<ElementType>(TokenStream stream,
      Iterable<ElementType Function(TokenStream)> generators, int limit) {
    var created = <ElementType>[];

    while (stream.hasCurrent() && (limit < 1 || created.length < limit)) {
      // We keep the exception thrown at the furthest point in parsing so
      //  that if nothing succeeds, we know what to complain about.
      var furthestException = InvalidSyntaxException('', -1, -1, -1);

      for (var pass in generators) {
        if (!stream.hasCurrent()) {
          break;
        }

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

  static List<Statement> statements(List<Token> tokens, {int limit = -1}) {
    return _parseRepeated(TokenStream(tokens, 0), _statementPasses, limit);
  }

  static Statement statement(TokenStream tokens) {
    return _parseRepeated(tokens, _statementPasses, 1)[0];
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
    if (tokens.isEmpty) {
      throw InvalidSyntaxException('Empty', 3, -1, -1);
    }

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

    var allParsed =
        _parseRepeated(TokenStream(tokens, 0), _expressionPasses, 1);

    if (allParsed.isEmpty) {
      throw RuntimeError('Unparsed!');
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

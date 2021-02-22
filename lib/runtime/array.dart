import 'exception.dart';
import 'handle.dart';
import 'primitive.dart';
import 'type.dart';
import 'value.dart';

class InitializerListType extends ValueType {
  @override
  TypeConversion conversionTo(ValueType to) {
    return TypeConversion.None;
  }

  @override
  Value convertObjectTo(Value object, ValueType endType) {
    return (object as InitializerList)
        .convertToArray((endType as ArrayType).elementType);
  }

  @override
  Value copyValue() {
    return this;
  }
}

class InitializerList extends Value {
  final contents = <Handle>[];

  @override
  Value copyValue() {
    throw RuntimeError('Cannot copy initialiser lists.');
  }

  @override
  bool equals(Value other) {
    throw RuntimeError('Cannot compare initialiser lists.');
  }

  @override
  bool greaterThan(Value other) {
    throw RuntimeError('Cannot compare initialiser lists.');
  }

  @override
  bool lessThan(Value other) {
    throw RuntimeError('Cannot compare initialiser lists.');
  }

  Value convertToArray(ValueType elementType) {
    var values = contents.map((e) => e.convertHandleTo(elementType)).toList();
    return ArrayValue(ArrayType(elementType), values);
  }

  @override
  Value mustConvertTo(ValueType endType) {
    if (!(endType is ArrayType)) {
      throw RuntimeError('Initialiser lists may only be converted to arrays.');
    }

    return convertToArray((endType as ArrayType).elementType);
  }
}

class ArrayValue extends Value {
  List<Handle> elements;

  ArrayValue(ArrayType arrayType, List<Handle> handles) {
    type = arrayType;

    elements = List<Handle>.filled(handles.length, null);

    for (var i = 0; i < handles.length; ++i) {
      elements[i] = handles[i].copyHandle();
    }
  }

  @override
  Value copyValue() {
    // The element handles will be copied by the constructor.
    return ArrayValue(type.copyValue() as ArrayType, elements);
  }

  @override
  bool equals(Value other) {
    if (other.type.conversionTo(type) != TypeConversion.NoConversion) {
      return false;
    }

    var otherArray = other as ArrayValue;
    if (elements.length != otherArray.elements.length) {
      return false;
    }

    for (var i = 0; i < elements.length; ++i) {
      if (elements[i].notEquals(otherArray.elements[i])) {
        return false;
      }
    }

    return true;
  }

  @override
  bool notEquals(Value other) {
    if (other.type.conversionTo(type) != TypeConversion.NoConversion) {
      return true;
    }

    var otherArray = other as ArrayValue;
    if (elements.length != otherArray.elements.length) {
      return true;
    }

    for (var i = 0; i < elements.length; ++i) {
      if (elements[i].notEquals(otherArray.elements[i])) {
        return true;
      }
    }

    return false;
  }

  // Not sure what to do with these yet.
  @override
  bool greaterThan(Value other) {
    throw UnimplementedError();
  }

  @override
  bool lessThan(Value other) {
    throw UnimplementedError();
  }

  @override
  Handle at(Value key) {
    return elements[(key as IntegerValue).rawValue];
  }

  @override
  Handle dot(String name) {
    if (name == 'length') {
      return IntegerValue.raw(elements.length).createHandle();
    }

    throw RuntimeError('Unable to find "$name" on type "$type".');
  }
}

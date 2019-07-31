module python.conv.python_to_d;


import python.raw: PyObject, pyListCheck, pyTupleCheck, PyTuple_Size;
import python.type: isUserAggregate, isTuple;
import std.traits: Unqual, isIntegral, isFloatingPoint, isAggregateType, isArray,
    isStaticArray, isAssociativeArray, isPointer, PointerTarget, isSomeChar, isSomeString, isSomeFunction;
import std.range: isInputRange;
import std.datetime: DateTime, Date;


T to(T)(PyObject* value) @trusted if(isIntegral!T) {
    import python.raw: PyLong_AsLong;

    const ret = PyLong_AsLong(value);
    if(ret > T.max || ret < T.min) throw new Exception("Overflow");

    return cast(T) ret;
}


T to(T)(PyObject* value) @trusted if(isFloatingPoint!T) {
    import python.raw: PyFloat_AsDouble;
    auto ret = PyFloat_AsDouble(value);
    return cast(T) ret;
}


T to(T)(PyObject* value) @trusted if(isUserAggregate!T) {
    import python.type: PythonClass, userAggregateInit;

    auto pyclass = cast(PythonClass!T*) value;
    auto ret = userAggregateInit!(Unqual!T);

    static foreach(i; 0 .. T.tupleof.length) {
        ret.tupleof[i] = pyclass.getField!i.to!(typeof(T.tupleof[i]));
    }

    // might need to be cast to `const` or `immutable`
    return cast(T) ret;
}


T to(T)(PyObject* value) if(isPointer!T && isUserAggregate!(PointerTarget!T)) {
    auto ret = new Unqual!(PointerTarget!T);
    *ret = to!(PointerTarget!T)(value);
    return ret;
}


T to(T)(PyObject* value) if(is(Unqual!T == DateTime)) {
    import python.raw;

    return DateTime(pyDateTimeYear(value),
                    pyDateTimeMonth(value),
                    pyDateTimeDay(value),
                    pyDateTimeHour(value),
                    pyDateTimeMinute(value),
                    pyDateTimeSecond(value));

}


T to(T)(PyObject* value) if(is(Unqual!T == Date)) {
    import python.raw;

    return Date(pyDateTimeYear(value),
                pyDateTimeMonth(value),
                pyDateTimeDay(value));
}


T to(T)(PyObject* value) if(isArray!T && !isSomeString!T)
    in(pyListCheck(value) || pyTupleCheck(value))
{
    import python.raw: PyList_Size, PyList_GetItem, PyTuple_Size, PyTuple_GetItem;
    import std.range: ElementEncodingType;
    import std.traits: Unqual;
    import std.exception: enforce;
    import std.conv: text;

    Unqual!T ret;

    static if(__traits(compiles, ret.length = 1)) {
        const valueLength = {
            if(pyListCheck(value))
                return PyList_Size(value);
            else if(pyTupleCheck(value))
                return PyTuple_Size(value);
            else
                assert(0);
        }();
        assert(valueLength >= 0, text("Invalid length ", valueLength));
        ret.length = valueLength;
    }

    foreach(i, ref elt; ret) {
        auto pythonItem = {
            if(pyListCheck(value))
                return PyList_GetItem(value, i);
            else if(pyTupleCheck(value))
                return PyTuple_GetItem(value, i);
            else
                assert(0);
        }();
        elt = pythonItem.to!(ElementEncodingType!T);
    }

    return ret;
}


T to(T)(PyObject* value) if(isSomeString!T) {
    import python.raw: pyUnicodeGetSize, pyUnicodeCheck,
        pyBytesAsString, pyObjectUnicode, pyUnicodeAsUtf8String, Py_ssize_t;
    import std.range: ElementEncodingType;
    import std.conv: to;

    value = pyObjectUnicode(value);

    const length = pyUnicodeGetSize(value);

    auto ptr = pyBytesAsString(pyUnicodeAsUtf8String(value));
    assert(length == 0 || ptr !is null);

    auto slice = ptr[0 .. length];

    return slice.to!T;
}


T to(T)(PyObject* value) if(is(Unqual!T == bool)) {
    import python.raw: pyTrue;
    return value is pyTrue;
}


T to(T)(PyObject* value) if(isAssociativeArray!T)
{
    import python.raw: pyDictCheck, PyDict_Keys, PyList_Size, PyList_GetItem, PyDict_GetItem;

    assert(pyDictCheck(value));

    // this enum is to get K and V whilst avoiding auto-decoding, which is why we're not using
    // std.traits
    enum _ = is(T == V[K], V, K);
    alias KeyType = Unqual!K;
    alias ValueType = Unqual!V;

    ValueType[KeyType] ret;

    auto keys = PyDict_Keys(value);

    foreach(i; 0 .. PyList_Size(keys)) {
        auto k = PyList_GetItem(keys, i);
        auto v = PyDict_GetItem(value, k);
        auto dk = k.to!KeyType;
        auto dv = v.to!ValueType;

        ret[dk] = dv;
    }

    return ret;
}


T to(T)(PyObject* value) if(isTuple!T)
    in(pyTupleCheck(value))
    in(PyTuple_Size(value) == T.length)
    do
{
    import python.raw: pyTupleCheck, PyTuple_Size, PyTuple_GetItem;

    T ret;

    static foreach(i; 0 .. T.length) {
        ret[i] = PyTuple_GetItem(value, i).to!(typeof(ret[i]));
    }

    return ret;
}


T to(T)(PyObject* value) if(isSomeChar!T) {
    auto str = value.to!string;
    return str[0];
}


T to(T)(PyObject* value) if(isSomeFunction!T) {
    return typeof(return).init;  // FIXME
}

record LocalAtomicObject {
  type objType;
  type atomicType = uint(64);
  var _atomicVar: atomic atomicType;

  inline proc read() {
    return __primitive("cast", objType, _atomicVar.read());
  }

  inline proc compareExchange(expectedObj:objType, newObj:objType) {
    if boundsChecking then
      if __primitive("is wide pointer", newObj) || __primitive("is wide pointer", expectedObj) then
        halt("Attempt to write a wide pointer into LocalAtomicObject");

    return _atomicVar.compareExchangeStrong(__primitive("cast", atomicType, expectedObj), __primitive("cast", atomicType, newObj));
  }

  inline proc write(newObj:objType) {
    if boundsChecking then
      if __primitive("is wide pointer", newObj) then
        halt("Attempt to write a wide pointer into LocalAtomicObject");
    _atomicVar.write(__primitive("cast", atomicType, newObj));
  }

  inline proc exchange(newObj:objType) {
    if boundsChecking then
      if __primitive("is wide pointer", newObj) then
        halt("Attempt to exchange a wide pointer into LocalAtomicObject");

    const curObj = _atomicVar.exchange(__primitive("cast", atomicType, newObj));
    return __primitive("cast", objType, curObj);
  }

  // handle wrong types
  proc write(newObj) {
    compilerError("Incompatible object type in LocalAtomicObject.write: ",
        newObj.type);
  }

  proc compareExchange(expectedObj, newObj) {
    compilerError("Incompatible object type in LocalAtomicObject.compareExchange: (",
        expectedObj.type, ",", newObj.type, ")");
  }

  proc exchange(newObj) {
    compilerError("Incompatible object type in LocalAtomicObject.exchange: ",
        newObj.type);
  }
}

class Foo {
  var x = 10;

  proc print() {
    writeln("Foo.x = ", x);
  }
}

proc main() {
  var tail: LocalAtomicObject(Foo);
  var initNode = new Foo(x=20);
  var newNode = new Foo(x=30);

  tail.write(initNode);
  tail.read().print();
  var oldNode = tail.exchange(newNode);
  oldNode.print();
  tail.read().print();
}
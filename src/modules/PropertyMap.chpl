const EmptyPropertyMap = new PropertyMap(string, string, true);

record PropertyMap {
    type vertexPropertyType;
    type edgePropertyType;
    var map : unmanaged PropertyMapImpl(vertexPropertyType, edgePropertyType);
    
    proc init(type vertexPropertyType, type edgePropertyType, param isEmpty = false) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        if !isEmpty then map = new unmanaged PropertyMapImpl(vertexPropertyType, edgePropertyType);
    }

    proc init(other : PropertyMap(?vertexPropertyType, ?edgePropertyType)) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        this.map = other.map;
    }

    proc clone(other : PropertyMap(?vertexPropertyType, ?edgePropertyType)) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        this.map = new unmanaged PropertyMap(other.map);
    }

    proc isInitialized return map != nil;

    forwarding map;
}

class PropertyMapping {
    type propertyType;
    var lock$ : sync bool;
    var dom : domain(propertyType);
    var arr : [dom] int;

    proc init(type propertyType) {
        this.propertyType = propertyType;
    }

    proc init(other : PropertyMapping(?propertyType)) {
        this.propertyType = propertyType;
        other.lock$.writeEF(true);
        this.dom = other.dom;
        this.arr = other.arr;
        other.lock$.readFE();
    }

    proc addProperty(property : propertyType) {
        lock$ = true;
        dom += property;
        arr[property] = -1;
        lock$;
    }

    proc setProperty(property : propertyType, id : int) {
        lock$ = true;
        dom += property;
        arr[property] = id;
        lock$;
    } 

    proc getProperty(property : propertyType) : int {
        lock$ = true;
        assert(dom.member(property), property, " was not found in: ", dom); 
        var retval = arr[property];
        lock$;
        return retval;
    }

    proc numProperties() : int {
        lock$ = true;
        var retval = dom.size;
        lock$;
        return retval;
    }

    iter these() : (propertyType, int) {
        for (prop, ix) in zip(dom, arr) do yield (prop, ix);
    }

    iter these(param tag : iterKind) : (propertyType, int) where tag == iterKind.standalone {
        forall (prop, ix) in zip(dom, arr) do yield (prop, ix);
    }
}

class PropertyMapImpl {
    type vertexPropertyType;
    type edgePropertyType;

    var vPropMap : owned PropertyMapping(vertexPropertyType);
    var ePropMap : owned PropertyMapping(edgePropertyType);

    proc init(type vertexPropertyType, type edgePropertyType) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        this.vPropMap = new owned PropertyMapping(vertexPropertyType);
        this.ePropMap = new owned PropertyMapping(edgePropertyType);
    }

    proc init(other : PropertyMapImpl(?vertexPropertyType, ?edgePropertyType)) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        this.vPropMap = new owned PropertyMapping(other.vPropMap);
        this.ePropMap = new owned PropertyMapping(other.ePropMap);
    }

    proc addVertexProperty(property : vertexPropertyType) {
        vPropMap.addProperty(property);
    }

    proc addEdgeProperty(property : edgePropertyType) {
        ePropMap.addProperty(property);
    }

    proc setVertexProperty(property : vertexPropertyType, id : int) {
        vPropMap.setProperty(property, id);
    }

    proc setEdgeProperty(property : edgePropertyType, id : int) {
        ePropMap.setProperty(property, id);
    }

    proc getVertexProperty(property : vertexPropertyType) : int {
        return vPropMap.getProperty(property);
    }

    proc getEdgeProperty(property : edgePropertyType) : int {
        return ePropMap.getProperty(property);
    }

    proc numVertexProperties() : int {
        return vPropMap.numProperties();
    }

    proc numEdgeProperties() : int {
        return ePropMap.numProperties();
    }

    iter vertexProperties() : (vertexPropertyType, int) {
        for (p,i) in vPropMap do yield (p,i);
    }

    iter vertexProperties(param tag : iterKind) : (vertexPropertyType, int) where tag == iterKind.standalone {
        forall (p,i) in vPropMap do yield (p,i);
    }

    iter edgeProperties() : (edgePropertyType, int) {
        for (p,i) in ePropMap do yield (p,i);
    }

    iter edgeProperties(param tag : iterKind) : (edgePropertyType, int) where tag == iterKind.standalone {
        forall (p,i) in ePropMap do yield (p,i);
    }
}

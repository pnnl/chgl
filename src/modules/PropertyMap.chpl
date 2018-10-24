const EmptyPropertyMap = new PropertyMap(string, string, true);

record PropertyMap {
    type vertexPropertyType;
    type edgePropertyType;
    var map : shared PropertyMapImpl(vertexPropertyType, edgePropertyType);
    
    proc init(type vertexPropertyType, type edgePropertyType, param isEmpty = false) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        if !isEmpty then map = new owned PropertyMapImpl(vertexPropertyType, edgePropertyType);
    }

    proc init(other : PropertyMap(?vertexPropertyType, ?edgePropertyType)) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        this.map = other.map;
    }

    proc clone(other : PropertyMap(?vertexPropertyType, ?edgePropertyType)) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        this.map = new PropertyMap(other.map);
    }

    proc isInitialized return map != nil;

    forwarding map;
}

record PropertyMapping {
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
}

class PropertyMapImpl {
    type vertexPropertyType;
    type edgePropertyType;

    var vPropMap : PropertyMapping(vertexPropertyType);
    var ePropMap : PropertyMapping(edgePropertyType);

    proc init(type vertexPropertyType, type edgePropertyType) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
    }

    proc init(other : PropertyMapImpl(?vertexPropertyType, ?edgePropertyType)) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        this.vPropMap = new PropertyMapping(other.vPropMap);
        this.ePropMap = new PropertyMapping(other.ePropMap);
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
}

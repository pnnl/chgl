record PropertyMap {
    type vertexPropertyType;
    type edgePropertyType;
    var map : owned PropertyMapImpl(vertexPropertyType, edgePropertyType);
    
    proc init(type vertexPropertyType, type edgePropertyType) {
        this.vertexPropertyType = vertexPropertyType;
        this.edgePropertyType = edgePropertyType;
        map = new owned PropertyMapImpl(vertexPropertyType, edgePropertyType);
    }

    forwarding map;
}

record PropertyMapping {
    var lock$ : sync bool;
    type propertyType;
    var dom : domain(propertyType);
    var arr : [dom] int;

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
}

class PropertyMapImpl {
    type vertexPropertyType;
    type edgePropertyType;

    var vPropMap : PropertyMapping(vertexPropertyType);
    var ePropMap : PropertyMapping(edgePropertyType);

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
}

prototype module UnrolledLinkedLists {

    class UnrollBlock {
        type eltType;
        param cap : int;
        var end : int;
        var start : int;
        var data : c_array(eltType, cap);
        var next : unmanaged UnrollBlock(eltType, cap)?;
    }

    record UnrolledLinkedList {
        type eltType;
        param unrollBlockSize : int;
        var sz : int;
        var head : unmanaged UnrollBlock(eltType, unrollBlockSize)?;
        proc init(type eltType, param unrollBlockSize : int) {
            this.eltType = eltType;
            this.unrollBlockSize = unrollBlockSize;
        }

        proc append(elt : eltType) {
            if head == nil {
                this.head = new unmanaged UnrollBlock(eltType, unrollBlockSize);
            } else if head!.end == unrollBlockSize {
                var newHead = new unmanaged UnrollBlock(eltType, unrollBlockSize);
                newHead.next = this.head;
                this.head = newHead;
            }
            this.head!.data[this.head!.end] = elt;
            this.head!.end += 1;
            this.sz += 1;
        }

        proc size return sz;

        proc remove(ref elt : ?eltType) : bool {
            if head == nil {
                return false;
            }
            if head!.start == head!.end {
                head = head!.next;
                if head == nil {
                    return false;
                }
            }
            elt = this.head!.data[this.head!.start];
            this.head!.start += 1;
            this.sz -= 1;
            return true;
        }

        iter these() : eltType {
            var block = this.head;
            while block != nil {
                for i in block!.start..block!.end {
                    yield block!.data[i];
                }
                block = block!.next;
            }
        }

        proc deinit() {
            var block = this.head;
            while block != nil {
                var tmp = block!.next;
                delete block;
                block = tmp;
            }
        }
    }

    // Proves that UnrolledLinkedList is faster than basic LinkedList and new List
    // Also shows that List is significantly slower than LinkedList and, which has already
    // been established is almost an order of magnitude slower than the naive push-back implementation.
    proc main() {
        use LinkedLists;
        use Time;
        use Vectors;
        use List;

        const numElems = 256 * 1024 * 1024;
        var timer = new Timer();

        {
            timer.start();
            var linkedList = new LinkedList(int);
            for i in 1..numElems {
                linkedList.push_back(i);
            }
            var total = 0;
            for i in linkedList do {
                total += i;
            }
            for i in 1..numElems {
                var x = linkedList.pop_front();
            }
            timer.stop();
            writeln("LinkedList finished in ", timer.elapsed(), "s");
            timer.clear();
        }
        
        {
            var l : list(int);
            timer.start();
            for i in 1..numElems {
                l.append(i);
            }
            var total = 0;
            for i in l do {
                total += i;
            }
            for i in 1..numElems {
                var x = l.pop();
            }
            timer.stop();
            writeln("List finished in ", timer.elapsed(), "s");
            timer.clear();
        }
        
        for param i in 1..10 {
            timer.clear();
            timer.start();
            var unrolledLinkedList = new UnrolledLinkedList(int, 2 ** i);
            for i in 1..numElems {
                unrolledLinkedList.append(i);
            }
            var total = 0;
            for i in unrolledLinkedList do {
                total += i;
            }
            for i in 1..numElems {
                var x : int;
                unrolledLinkedList.remove(x);
            }
            timer.stop();
            writeln("UnrolledLinkedList with unrollBlockSize ", 2 ** i, " finished in ", timer.elapsed(), "s");
        }
    }
}

use Spawn;
use Time;

record PlotterData {
  type xAxisType;
  type yAxisType;

  var data : [{0..-1}] (xAxisType, yAxisType);
}

// A plotting device that can be used to add/remove plot data.
record Plotter {
  type xAxisType;
  type yAxisType;

  var plotDataDom : domain(string);
  var plotData : [plotDataDom] PlotterData(xAxisType, yAxisType);


  inline proc stringify(data : [?dataDom] ?tupleType) {
    var str : string;
    for tpl in data {
      for param i in 1..tpl.size {
        if i != 1 then str = str + ",";
        str = str + tpl[i];
      }
      str = str + "\n";
    }
    return str;
  }

  proc add(name : string, x : xAxisType, y : yAxisType) {
    plotDataDom += name;
    plotData[name].data.push_back((x, y));
  }

  // data : [] PlotData
  proc plot(outputFile : string) {
    var plotCmd : string;

    // Create filename for each unique domain and add elements to be plotted...
    for name in plotDataDom {
      var tmpFile = open(name + ".dat", iomode.cw);
      var writer = tmpFile.writer();
      writeln(stringify(plotData[name].data));
      writer.write(stringify(plotData[name].data));
      writer.close();

      plotCmd = plotCmd + "'" + name + ".dat' using 1:2:xtic(1) with lines title '" + name + "', ";
    }

    var cmd : string = "gnuplot -e \"set terminal pngcairo size 1920,1080 enhanced font 'Verdana,10';\n";
    cmd = cmd + "set output '" + outputFile + ".png';\n";
    cmd = cmd + "set datafile separator ',';\n";
    cmd = cmd + "plot " + plotCmd;
    cmd = cmd + "\"";

    var sub = spawnshell([cmd]);
    sub.communicate();
    writeln("Done");
  }
}

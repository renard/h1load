#!/bin/bash

# -t <name> forces the name on the graph
if [ "$1" = "-t" ]; then
   name="$2"
   shift; shift
fi

for i in "$@"; do
  # If the file name is "run..." then we'll look for a "ref..." file which
  # will be used to retrieve direct response times.
  run="${i}"
  ref="${i#cli-run-}"
  ref="cli-ref-${ref}"

  # take only what's after ':' if present in the file name, and stop
  # before the last dot (file name extension).
  if [ -z "$name" ]; then
     name="${i%.*}"
     name="${name##*:}"
  fi
gnuplot <<EOF
  set title "$name"
  set grid lt 0 lw 1 ls 1 lc rgb "#d0d0d0"
  set yrange [0:]
  set ytics nomirror
  set y2range [0:]
  set y2tics 200
  set xlabel "Time(s)" offset 0,0.5
  set ylabel "Requests per second"
  set y2label "Nb conn, Latency (�s)"
  #set key inside bottom center box
  set key outside bottom center horizontal spacing 1.5 reverse Left samplen 3 spacing 2
  #set terminal png font courbi 9 size 800,400
  set terminal pngcairo size 800,400 background rgb "#f0f0f0"
  set style fill transparent solid 0.10 noborder
  set format y "%.0f"
  set format y2 "%.0f"
  set output "${i%.*}.png"

  stats "$run" using 1 nooutput; min_time_run=STATS_min
  stats "$ref" using 1 nooutput; min_time_ref=STATS_min
  x_offset=(min_time_run < min_time_ref) ? min_time_run : min_time_ref

  stats "$ref" using 1 nooutput
  min_time_ref=STATS_min

  stats "$run" using 1:2 nooutput
  conmax=(int((STATS_max_y-0.0001)/(10**(int(log10(STATS_max_y)-1)))/5)*5+5)*(10**(int(log10(STATS_max_y)-1)))

  stats "$run" using 1:9 nooutput
  rpsmax=(int((STATS_max_y-0.0001)/(10**(int(log10(STATS_max_y)-1)))/5)*5+5)*(10**(int(log10(STATS_max_y)-1)))

  stats "$run" using 1:12 nooutput
  latmax=(int((STATS_max_y-0.0001)/(10**(int(log10(STATS_max_y)-1)))/5)*5+5)*(10**(int(log10(STATS_max_y)-1)))

  y2max=(latmax>conmax)?latmax:conmax
  set y2range[0:y2max]
  set y2tics y2max/10

  set yrange[0:rpsmax]
  set ytics rpsmax/10

  # reminder on LT: 1=magenta, 2=green, 3=light blue, 4=dark yellow, 5=light yellow, 6=dark blue, 7=red, 8=black
  plot \
    "$run" using (\$1-x_offset):2  with filledcurves x1 notitle axis x1y2 lt 3, \
    "$run" using (\$1-x_offset):12 with filledcurves x1 notitle axis x1y2 lt 1, \
    "$run" using (\$1-x_offset):9  with filledcurves x1 notitle lt 2, \
    "$ref" using (\$1-x_offset):12 with filledcurves x1 notitle axis x1y2 lt 7, \
    "$run" using (\$1-x_offset):9  with lines title "<- Req/s" lt 2 lw 3, \
    "$run" using (\$1-x_offset):2  with lines title "Nb conn ->" axis x1y2 lt 3 lw 3, \
    "$run" using (\$1-x_offset):12 with lines title "Latency (�s) ->" axis x1y2 lt 1 lw 3, \
    "$ref" using (\$1-x_offset):12 with lines title "Direct (�s) ->" axis x1y2 lt 7 lw 1
EOF
done

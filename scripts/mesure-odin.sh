#!/system/bin/sh
# Une ligne : images en 10 s, charge GPU, CPU max (m°C), GPU max (m°C).
f=$(grep "present intervals" /sdcard/WC14/fifawc14.log | tail -1 | grep -o 'interval 1: [0-9]*' | grep -o '[0-9]*$')
[ -z "$f" ] && f=0
g=$(cat /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage | tr -d ' %')
c=0; p=0
for z in /sys/class/thermal/thermal_zone*; do
  case $(cat $z/type) in
    cpu-*) t=$(cat $z/temp); [ "$t" -gt "$c" ] && c=$t ;;
    gpuss-*) t=$(cat $z/temp); [ "$t" -gt "$p" ] && p=$t ;;
  esac
done
echo "$f $g $c $p"

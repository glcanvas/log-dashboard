sleep 5

while true; do
    res="$(clickhouse-client --host clickhouse01 -nm < /db/init.sql)"
    echo "Output: $res"
    success="$(echo "$res" | grep webshop)"
    if [ ! -z "$success" ]; then
        break;
    fi;
    echo trying
    sleep 1;
done;
echo finished

使用方式

```

docker run --rm -v "$(pwd)":/out swr.cn-southwest-2.myhuaweicloud.com/gsc-hub/file:20260816_135406-x86_64 \
sh -c "cat /tmp/file.part-* > /out/file"

```

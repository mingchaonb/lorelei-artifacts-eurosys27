# libuv 1.52.1 validation (TLC + HLR)

This recipe builds the official libuv 1.52.1 shared library. The directed workload submits one `uv_queue_work` request, requires its worker callback on the host thread pool and its completion callback on the event loop, closes the loop, and shuts down libuv in both native and Hecate paths.

```bash
./evaluations/1-libs/libuv/run.sh --reference --verbose /path/to/lorelei-devkit
```

TLC callback replacement is disabled. HLR rewrites the production shared-library closure. A reviewed patch leaves libuv's host-internal static worker tables at raw host addresses because those functions do not cross the guest boundary. Network, filesystem, process, signal, synchronization, platform-specific backends, and the complete upstream test suite are outside this directed callback workload.

The expected audit is 35 translation units, 7 CCG classes, 6 FDG classes, and 14 rewritten files.

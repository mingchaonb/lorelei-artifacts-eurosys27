#include <uv.h>
#include <stdio.h>

struct State {
   int worker_calls;
   int after_calls;
   int status;
};

static void worker_callback(uv_work_t *request)
{
   struct State *state = request->data;
   ++state->worker_calls;
   fprintf(stderr, "worker callback complete\n");
}

static void after_callback(uv_work_t *request, int status)
{
   struct State *state = request->data;
   ++state->after_calls;
   state->status = status;
   fprintf(stderr, "after callback complete\n");
}

int main(void)
{
   uv_loop_t *loop = uv_default_loop();
   uv_work_t request;
   struct State state = {0, 0, -1};
   int rc;

   request.data = &state;
   rc = uv_queue_work(loop, &request, worker_callback, after_callback);
   if (rc != 0) {
      fprintf(stderr, "uv_queue_work: %s\n", uv_strerror(rc));
      return 2;
   }
   rc = uv_run(loop, UV_RUN_DEFAULT);
   fprintf(stderr, "uv_run complete rc=%d\n", rc);
   if (rc != 0)
      return 3;
   rc = uv_loop_close(loop);
   fprintf(stderr, "uv_loop_close complete rc=%d\n", rc);
   uv_library_shutdown();
   fprintf(stderr, "uv_library_shutdown complete\n");
   printf("worker_calls=%d after_calls=%d status=%d close=%d\n",
          state.worker_calls, state.after_calls, state.status, rc);
   return state.worker_calls == 1 && state.after_calls == 1 &&
          state.status == 0 && rc == 0 ? 0 : 4;
}

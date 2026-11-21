/* LD_PRELOAD crash reporter: on SIGSEGV/SIGBUS/SIGABRT/SIGILL prints pc, lr, fault address,
   a frame-pointer walk and the executable mappings, using only async-signal-safe calls. */
#define _GNU_SOURCE
#include <signal.h>
#include <ucontext.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

static void ws(const char *s) { write(2, s, strlen(s)); }
static void wx(uint64_t v) { char b[19]; b[0]='0'; b[1]='x'; for (int i = 0; i < 16; i++) { int n = (v >> (60 - 4*i)) & 15; b[2+i] = n < 10 ? '0'+n : 'a'+n-10; } b[18]=0; ws(b); }
static char stack[65536];

static void dump_maps(void) {
  int fd = open("/proc/self/maps", O_RDONLY); if (fd < 0) return;
  char buf[4096], line[512]; int ll = 0; ssize_t n;
  while ((n = read(fd, buf, sizeof buf)) > 0) for (ssize_t i = 0; i < n; i++) {
    if (ll < (int)sizeof line - 1) line[ll++] = buf[i];
    if (buf[i] == '\n') { line[ll] = 0; char *p = strchr(line, ' '); if (p && p[3] == 'x') { ws("  map "); ws(line); } ll = 0; }
  }
  close(fd);
}

static void handler(int sig, siginfo_t *si, void *ctx) {
  ucontext_t *uc = (ucontext_t *)ctx;
  ws("\n=== SEGVTRACE signal "); wx(sig); ws(" pid "); wx(getpid()); ws(" fault_addr "); wx((uint64_t)si->si_addr);
  ws("\n  pc "); wx(uc->uc_mcontext.pc); ws("\n  lr "); wx(uc->uc_mcontext.regs[30]); ws("\n  sp "); wx(uc->uc_mcontext.sp);
  ws("\n  x0 "); wx(uc->uc_mcontext.regs[0]); ws(" x1 "); wx(uc->uc_mcontext.regs[1]); ws(" x2 "); wx(uc->uc_mcontext.regs[2]);
  ws("\n  frame walk:\n");
  uint64_t fp = uc->uc_mcontext.regs[29], sp = uc->uc_mcontext.sp;
  for (int i = 0; i < 24 && fp && (fp & 7) == 0 && fp >= sp && fp - sp < (64u << 20); i++) {
    uint64_t *f = (uint64_t *)fp; ws("    ret "); wx(f[1]); ws("\n"); if (f[0] <= fp) break; fp = f[0];
  }
  ws("  executable mappings:\n"); dump_maps(); ws("=== SEGVTRACE end\n");
  signal(sig, SIG_DFL); raise(sig);
}

__attribute__((constructor)) static void init(void) {
  stack_t ss = { .ss_sp = stack, .ss_size = sizeof stack, .ss_flags = 0 }; sigaltstack(&ss, 0);
  struct sigaction sa; memset(&sa, 0, sizeof sa); sa.sa_sigaction = handler; sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
  sigaction(SIGSEGV, &sa, 0); sigaction(SIGBUS, &sa, 0); sigaction(SIGILL, &sa, 0); sigaction(SIGABRT, &sa, 0);
  if (getenv("SEGVTRACE_VERBOSE")) ws("segvtrace loaded\n");
}

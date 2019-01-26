#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
  char cmd[256];
  if (argc < 3)
  {
    printf("Invokes exomizer3 raw mode with max.seq.length 256\nUsage: pack3 <infile> <outfile>\n");
    return 1;
  }

  sprintf(cmd, "exomizer3 raw -T4 -M256 -c -o%s %s", argv[2], argv[1]);
  return system(cmd);
}

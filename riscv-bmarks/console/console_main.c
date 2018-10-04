void putchar(char ch)
{
  asm volatile ("mtpcr %0,$cr18" : : "r"(ch));
}

void putstr(char* str)
{
  while(*str)
    putchar(*str++);
}

void quit()
{
  int one = 1;
  asm volatile ("mtpcr %0,$cr16" : : "r"(one));
}

int main()
{
  putstr("Hello, world!\n");
  quit();
  return 0;
}

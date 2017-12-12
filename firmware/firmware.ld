ENTRY("_start")
SECTIONS
{
  .text 0x0 :
  {
    *(.text)
  }
  .data :
  {
    *(.data)
  }
  .bss :
  {
    *(.bss)
      *(COMMON)
  }
}

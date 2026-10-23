/*
 * STM32F103C8T6 链接脚本（GNU ld）
 *
 * MCU: Cortex-M3 / 64 KiB Flash / 20 KiB SRAM
 * 工程: STM32F10x StdPeriph + GNU Arm Embedded Toolchain
 * 启动文件: startup_stm32f10x_md.s (gcc_ride7 版本)
 *
 * 核心思路：
 *   1. 中断向量表、程序代码、只读数据 -> Flash
 *   2. .data 变量 -> 运行时在 SRAM，初始内容保存在 Flash
 *   3. .bss 变量  -> 运行时在 SRAM，上电时由 Startup 清零
 *   4. 初始 MSP  -> 指向 SRAM 末尾（栈向低地址增长）
 *
 * 注意：本文件负责分配地址，不会自动执行 .data 复制或 .bss 清零。
 *       这些工作由 Reset_Handler 完成。
 */

/* 指定 ELF 文件头所记录的程序入口符号。STM32 复位时实际读取的是向量表。 */
ENTRY(Reset_Handler)

/* -------------------------------------------------------------------------
 * MEMORY：声明芯片有哪些可用的存储器，以及它们的地址和大小。
 * ------------------------------------------------------------------------- */
MEMORY
{
    /* rx  = 可读取、可执行；STM32 的固件主要放在 Flash 中。 */
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 64K

    /* xrw = 可执行、可读取、可写入（是链接器使用的区域属性）。 */
    RAM   (xrw) : ORIGIN = 0x20000000, LENGTH = 20K
}

/* 栈向低地址增长；所以初始栈指针放在 SRAM 结束边界 0x20005000。 */
_estack = ORIGIN(RAM) + LENGTH(RAM);

/* 预留空间的最小值，可按项目需要调整。
 * 注意：这不是把堆和栈“分配好并管理起来”，而是帮助链接阶段检查
 *       .data/.bss 之外是否还留有足够的 RAM 余量。
 *       0x200 = 512 字节，0x400 = 1024 字节。
 */
_Min_Heap_Size  = 0x200;
_Min_Stack_Size = 0x400;

/* -------------------------------------------------------------------------
 * SECTIONS：告诉链接器如何把各个 .o 文件中的输入节，
 *           组合成最终 ELF 的输出节，并将它们安排到 Flash / SRAM。
 * ------------------------------------------------------------------------- */
SECTIONS
{
    /* 1. 中断向量表：必须首先放在用户 Flash 的起始位置。
     * 向量表的第一项是初始 MSP，第二项是 Reset_Handler 地址。
     */
    .isr_vector :
    {
        . = ALIGN(4);                 /* 当前位置按 4 字节对齐 */
        KEEP(*(.isr_vector))          /* 收集所有 .isr_vector；禁止垃圾回收删除 */
        . = ALIGN(4);
    } > FLASH                          /* 输出节的运行/存储地址都位于 Flash */

    /* 2. 程序代码：main、Reset_Handler、StdPeriph 驱动函数等。 */
    .text :
    {
        . = ALIGN(4);
        *(.text)                      /* 收集名为 .text 的输入节 */
        *(.text.*)                    /* 收集 .text.main、.text.Reset_Handler 等 */
        *(.glue_7)                    /* ARM/Thumb 互操作相关节（如有） */
        *(.glue_7t)
        KEEP(*(.init))                /* 部分运行库可能使用的初始化节 */
        KEEP(*(.fini))                /* 部分运行库可能使用的结束节 */
        . = ALIGN(4);
    } > FLASH

    /* 3. 只读数据：例如 const 查找表、字符串字面量。 */
    .rodata :
    {
        . = ALIGN(4);
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
    } > FLASH

    /* 4. ARM 工具链可能生成的栈展开 / 异常处理辅助信息。
     *    简单的纯 C 裸机工程可能几乎用不到，但显式安排更稳妥。
     */
    .ARM.extab :
    {
        *(.ARM.extab* .gnu.linkonce.armextab.*)
    } > FLASH

    .ARM.exidx :
    {
        __exidx_start = .;
        *(.ARM.exidx* .gnu.linkonce.armexidx.*)
        __exidx_end = .;
    } > FLASH

    /* 5. 某些 C/C++ 运行库使用的初始化/清理函数指针列表。
     *    “放进 Flash”不代表自动调用；如果以后使用 C++ 全局对象，
     *    还需要确认 Reset_Handler 是否调用了 __libc_init_array()。
     */
    .preinit_array :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN(__preinit_array_start = .);
        KEEP(*(.preinit_array*))
        PROVIDE_HIDDEN(__preinit_array_end = .);
        . = ALIGN(4);
    } > FLASH

    .init_array :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN(__init_array_start = .);
        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array*))
        PROVIDE_HIDDEN(__init_array_end = .);
        . = ALIGN(4);
    } > FLASH

    .fini_array :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN(__fini_array_start = .);
        KEEP(*(SORT(.fini_array.*)))
        KEEP(*(.fini_array*))
        PROVIDE_HIDDEN(__fini_array_end = .);
        . = ALIGN(4);
    } > FLASH

    /* 6. .data：有初始值、运行时可修改的全局/静态变量。
     *
     * 例如 int count = 100;
     *   LMA（初始内容位置）：Flash，断电后仍保存数值 100。
     *   VMA（运行位置）    ：SRAM，程序可以对 count 进行写操作。
     *
     * LOADADDR(.data) 取 .data 在 Flash 中的加载起始地址。
     */
    _sidata = LOADADDR(.data);

    .data :
    {
        . = ALIGN(4);
        _sdata = .;                   /* SRAM 中 .data 的起始地址 */
        *(.data)
        *(.data.*)
        . = ALIGN(4);
        _edata = .;                   /* SRAM 中 .data 的结束边界（不包含） */
    } > RAM AT > FLASH                /* 运行时在 RAM；初始镜像放在 Flash */

    /* Reset_Handler 用 _sidata、_sdata、_edata 复制初始化数据。 */

    /* 7. .bss：需要启动时清零的全局/静态变量。
     *
     * 例如 int buffer[100];
     * NOLOAD：不需要在固件中保存一大块对应的零字节。
     */
    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        _sbss = .;                    /* SRAM 中 .bss 的起始地址 */
        __bss_start__ = _sbss;        /* 为部分运行库提供兼容别名 */
        *(.bss)
        *(.bss.*)
        *(COMMON)                     /* 兼容较旧编译模式生成的 common 符号 */
        . = ALIGN(4);
        _ebss = .;                    /* SRAM 中 .bss 的结束边界（不包含） */
        __bss_end__ = _ebss;
    } > RAM

    /* Reset_Handler 用 _sbss、_ebss 将这段 SRAM 清零。 */

    /* 8. 为堆和栈预留最小余量，并辅助链接器进行 SRAM 容量检查。
     *
     * 这里没有建立实际的动态内存分配器，也不能检测运行时栈溢出。
     * 真正的栈初始位置仍由上面的 _estack 指定。
     */
    ._user_heap_stack (NOLOAD) :
    {
        . = ALIGN(8);
        PROVIDE(end = .);
        PROVIDE(_end = .);
        . = . + _Min_Heap_Size;
        . = . + _Min_Stack_Size;
        . = ALIGN(8);
    } > RAM

    /* 9. 丢弃不需要写入目标固件的编译器辅助元数据。
     *    调试信息（例如 .debug_*）没有在这里删除，ELF 中仍可保留。
     */
    /DISCARD/ :
    {
        *(.note.GNU-stack)
        *(.comment)
    }
}

/* 明确检查：正常 STM32 用户 Flash 启动必须有向量表，且位于 Flash 起点。 */
ASSERT(SIZEOF(.isr_vector) > 0, "ERROR: .isr_vector is empty; check the startup file!")
ASSERT(ADDR(.isr_vector) == ORIGIN(FLASH), "ERROR: vector table is not at FLASH start!")

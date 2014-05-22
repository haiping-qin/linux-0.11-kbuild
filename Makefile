# To put more focus on warnings, be less verbose as default
# Use 'make V=1' to see the full commands

ifeq ("$(origin V)", "command line")
  BUILD_VERBOSE := $(V)
endif
ifeq ($(BUILD_VERBOSE),1)
  quiet =
  Q =
else
  quiet=quiet_
  Q = @
endif

# Running 'make -s' to suppress echoing of commands

ifneq ($(filter s% -s%,$(MAKEFLAGS)),)
  quiet=silent_
endif

export quiet Q

HOSTOS := $(shell uname -s | tr '[:upper:]' '[:lower:]' | \
	    sed -e 's/\(cygwin\).*/windows/')

ifeq ($(HOSTOS), linux)
  CROSS_COMPILE	:=
else ifeq ($(HOSTOS), darwin)
  CROSS_COMPILE	:= i386-elf-
else
  # TODO: build on Windows
  $(error "Unkown host!")
endif

# Default target
PHONY := all
all:

MAKEFLAGS += -rR --no-print-directory

# We need some generic definitions
include tools/include.mk

# Make variables

CC		= $(CROSS_COMPILE)gcc
AS		= $(CROSS_COMPILE)as --32 -g
LD		= $(CROSS_COMPILE)ld
AR		= $(CROSS_COMPILE)ar
NM		= $(CROSS_COMPILE)nm
OBJCOPY		= $(CROSS_COMPILE)objcopy
OBJDUMP		= $(CROSS_COMPILE)objdump
SHELL		= sh

CFLAGS		:= -Iinclude -g -m32 -fno-builtin -fno-stack-protector \
		   -fomit-frame-pointer -fstrength-reduce -nostdinc
AFLAGS		:= -Iinclude -g -m32 -DASSEMBLY -nostdinc
LDFLAGS		:= -m elf_i386
OBJCOPYFLAGS	:= -R .pdr -R .comment -R.note -S -O binary

LDFLAGS_bootsect:= -Ttext 0
LDFLAGS_setup	:= -Ttext 0
LDFLAGS_system	:= -Ttext 0 -e startup_32

export CC AS LD AR NM OBJCOPY OBJDUMP SHELL
export CFLAGS AFLAGS LDFLAGS OBJCOPYFLAGS

#
# ROOT_DEV specifies the default root-device when making the image.
# give it one the the following values:
#   030n (/dev/hdn, n=0,..,4, first hard disk, n'st partition)
#   030n (/dev/hdn, n=5,..,9, second hard disk, (n-5)'st partition)
#   0208 (/dev/at0)
#   0209 (/dev/at1)
#   021c (/dev/fd0)
#   021d (/dev/fd1)
# or leave it empty, it will be set to default 0301.
#
ROOT_DEV=

all: Image

system-y	:= boot/ init/ kernel/ mm/ fs/ lib/
system-dirs	:= $(patsubst %/,%, $(filter %/, $(system-y)))
system-all	:= $(patsubst %/, %/built-in.o, $(system-y))

quiet_cmd_ld = LD      $@
      cmd_ld = $(LD) $(LDFLAGS) $(LDFLAGS_$(@F)) \
	       $(filter-out FORCE,$^) -o $@ 

quiet_cmd_objcopy = OBJCOPY $@
      cmd_objcopy = $(OBJCOPY) $(OBJCOPYFLAGS) $(OBJCOPYFLAGS_$(@F)) $< $@

Image: tools/bootsect.bin tools/setup.bin tools/system.bin
	@echo "  BUILD   $@"
	$(Q)$(SHELL) tools/build.sh $^ $@ $(ROOT_DEV)

tools/%.bin: tools/%
	$(call if_changed,objcopy)

tools/bootsect: boot/bootsect.o
	$(call if_changed,ld)

tools/setup: boot/setup.o
	$(call if_changed,ld)

boot/setup.o boot/bootsect.o: boot ;

tools/system: $(system-all)
	$(call if_changed,ld)
	$(Q)$(NM) $@ | \
	  grep -v '\(compiled\)\|\(\.o$$\)\|\( [aU] \)\|\(\.\.ng$$\)\|\(LASH[RL]DI\)'| \
	  sort > $@.map

# The actual objects are generated when descending, 
# make sure no implicit rule kicks in
$(sort $(system-all)): $(system-dirs) ;

PHONY += $(system-dirs)
$(system-dirs):
	$(Q)$(MAKE) $(build)=$@

clean:
	@find . \( -name '*.[os]' -o -name '.*.cmd' -o -name '.*.d' -o -name '.*.tmp' \
		-o -name lib.a \) -type f -print | xargs rm -f
	@rm -f Image tools/system* tools/setup* tools/bootsect* tools/build

distclean:
	@find . -name '.*.swp' -delete
	@rm -rf cscope* tags

# read all saved dependency lines
#
targets := $(wildcard $(sort $(targets)))
cmd_files := $(wildcard .*.cmd $(foreach f,$(targets),$(dir $(f)).$(notdir $(f)).cmd))

ifneq ($(cmd_files),)
  $(cmd_files): ;        # Do not try to update included dependency files
  include $(cmd_files)
endif

PHONY += FORCE
FORCE:

.PHONY: $(PHONY)

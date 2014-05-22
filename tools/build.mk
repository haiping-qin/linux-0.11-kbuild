# ==========================================================================
# Building
# ==========================================================================

PHONY := __build
__build:

# Init all relevant variables so they do not
# inherit any value from the environment
obj-y :=
extra-y :=
targets :=
subdir-y :=

include tools/include.mk
include $(obj)/Makefile

# Handle objects in subdirs
# ---------------------------------------------------------------------------
# o if we encounter foo/ in $(obj-y), replace it by foo/built-in.o
#   and add the directory to the list of dirs to descend into: $(subdir-y)

subdir-y	:= $(patsubst %/,%,$(filter %/, $(obj-y)))
obj-y		:= $(patsubst %/, %/built-in.o, $(obj-y))

# $(subdir-obj-y) is the list of objects in $(obj-y) which uses dir/ to
# tell kbuild to descend
subdir-obj-y	:= $(filter %/built-in.o, $(obj-y))

obj-y		:= $(addprefix $(obj)/,$(obj-y))
extra-y         := $(addprefix $(obj)/,$(extra-y))
subdir-obj-y	:= $(addprefix $(obj)/,$(subdir-obj-y))
subdir-y	:= $(addprefix $(obj)/,$(subdir-y))

c_flags		= -Wp,-MD,$(depfile) $(CFLAGS)
a_flags		= -Wp,-MD,$(depfile) $(AFLAGS)
ld_flags	= $(LDFLAGS)

ifneq ($(strip $(obj-y)),)
builtin-target := $(obj)/built-in.o
endif

__build: $(builtin-target) $(extra-y) $(subdir-y)
	@:

# Compile C and assembler sources (.c, .S)
# ---------------------------------------------------------------------------

quiet_cmd_cc_o_c = CC      $@
      cmd_cc_o_c = $(CC) $(c_flags) -c -o $@ $<

$(obj)/%.o: $(obj)/%.c FORCE
	$(call if_changed_dep,cc_o_c)

quiet_cmd_as_o_S = AS      $@
	cmd_as_o_S = $(CC) $(a_flags) -c -o $@ $<

$(obj)/%.o: $(obj)/%.S FORCE
	$(call if_changed_dep,as_o_S)

targets += $(obj-y) $(extra-y) $(MAKECMDGOALS)

# Build the compiled-in targets
# ---------------------------------------------------------------------------

# To build objects in subdirs, we need to descend into the directories
$(sort $(subdir-obj-y)): $(subdir-y) ;

#
# Rule to compile a set of .o files into one .o file
#
ifdef builtin-target
quiet_cmd_link_o_target = LD      $@
# If the list of objects to link is empty, just create an empty built-in.o
cmd_link_o_target = $(if $(strip $(obj-y)),\
		      $(LD) $(ld_flags) -r -o $@ $(filter $(obj-y), $^), \
		      rm -f $@; $(AR) rcs$(ARFLAGS) $@)

$(builtin-target): $(obj-y) FORCE
	$(call if_changed,link_o_target)

targets += $(builtin-target)
endif

# Descending
# ---------------------------------------------------------------------------

PHONY += $(subdir-y)
$(subdir-y):
	$(Q)$(MAKE) $(build)=$@

# Add FORCE to the prequisites of a target to force it to be always rebuilt.
# ---------------------------------------------------------------------------

PHONY += FORCE
FORCE:

# Read all saved command lines and dependencies for the $(targets) we
# may be building above, using $(if_changed{,_dep}). As an
# optimization, we don't need to read them if the target does not
# exist, we will rebuild anyway in that case.

targets := $(wildcard $(sort $(targets)))
cmd_files := $(wildcard $(foreach f,$(targets),$(dir $(f)).$(notdir $(f)).cmd))

ifneq ($(cmd_files),)
  include $(cmd_files)
endif

# Declare the contents of the .PHONY variable as phony.  We keep that
# information in a variable se we can use it in if_changed and friends.

.PHONY: $(PHONY)

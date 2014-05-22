####
# kbuild: Generic definitions

# Convenient variables
comma   := ,
squote  := '
empty   :=
space   := $(empty) $(empty)

###
# Name of target with a '.' as filename prefix. foo/bar.o => foo/.bar.o
dot-target = $(dir $@).$(notdir $@)

###
# The temporary file to save gcc -MD generated dependencies must not
# contain a comma
depfile = $(subst $(comma),_,$(dot-target).d)

###
# filename of target with directory and extension stripped
basetarget = $(basename $(notdir $@))

###
# Escape single quote for use in echo statements
escsq = $(subst $(squote),'\$(squote)',$1)

###
# Easy method for doing a status message
       kecho := :
 quiet_kecho := echo
silent_kecho := :
kecho := $($(quiet)kecho)

###
# Shorthand for $(Q)$(MAKE) -f tools/build.mk obj=
# Usage:
# $(Q)$(MAKE) $(build)=dir
build := -f tools/build.mk obj

# echo command.
# Short version is used, if $(quiet) equals `quiet_', otherwise full one.
echo-cmd = $(if $($(quiet)cmd_$(1)),\
	echo '  $(call escsq,$($(quiet)cmd_$(1)))';)

# printing commands
cmd = @$(echo-cmd) $(cmd_$(1))

cmd_dep = @set -e; $(echo-cmd) $(cmd_$(1)); \
	sed -e 's|.*:|$@:|;s|h$$|h \;|' < $(depfile) > $(dot-target).tmp;    \
	mv -f $(dot-target).tmp $(depfile)

# Check if both arguments has same arguments. Result is empty string if equal.
arg-check = $(strip $(filter-out $(cmd_$(1)), $(cmd_$@)) \
                    $(filter-out $(cmd_$@), $(cmd_$(1))) )

# >'< substitution is for echo to work,
# >$< substitution to preserve $ when reloading .cmd file
make-cmd = $(subst \\,\\\\,$(subst \#,\\\#,$(subst $$,$$$$,$(call escsq,$(cmd_$(1))))))

# Find any prerequisites that is newer than target or that does not exist.
# PHONY targets skipped in both cases.
any-prereq = $(filter-out $(PHONY),$?) $(filter-out $(PHONY) $(wildcard $^),$^)

# Execute command if command has changed or prerequisite(s) are updated.
if_changed = $(if $(strip $(any-prereq) $(arg-check)),                       \
	@set -e;                                                             \
	$(echo-cmd) $(cmd_$(1));                                             \
	echo 'cmd_$@ := $(make-cmd)' > $(dot-target).cmd)

# Execute the command and also postprocess generated .d dependencies file.
if_changed_dep = $(if $(strip $(any-prereq) $(arg-check)),                   \
	@set -e;                                                             \
	$(echo-cmd) $(cmd_$(1));                                             \
	printf 'cmd_$@ := $(make-cmd)\n\n' > $(dot-target).tmp;              \
	printf 'source_$@ := $<\n\n' >> $(dot-target).tmp;                   \
	sed -e 's|.*: $<|deps_$@ := \\\n|' < $(depfile) >> $(dot-target).tmp;\
	sed -i -e 's|^ |    |' $(dot-target).tmp;                            \
	printf '\n$@: $$(deps_$@)' >> $(dot-target).tmp;                     \
	printf '\n\n$$(deps_$@):' >> $(dot-target).tmp;                      \
	rm -f $(depfile);                                                    \
	mv -f $(dot-target).tmp $(dot-target).cmd)

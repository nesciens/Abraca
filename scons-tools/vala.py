# Copyright (c) 2008, Abraca Team
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

import SCons

def vala_emitter(target, source, env):
	target = []

	for src in source:
		tgt = src.target_from_source('', '.c')
		env.SideEffect(src.target_from_source('', '.h'), src)
		target.append(tgt)

	return target, source

def generate(env):
	env['VALAC'] = env.get('VALAC', 'valac')
	env['VALACOM'] = '$VALAC --quiet -C -d $TARGET.dir $VALAFLAGS $_VALAPKGPATHS $_VALAPKGS $SOURCES'
	env['VALAFLAGS'] = SCons.Util.CLVar('')

	env['VALAPKGS'] = SCons.Util.CLVar('')
	env['VALAPKGPREFIX'] = '--pkg='
	env['_VALAPKGS'] = '${_defines(VALAPKGPREFIX, VALAPKGS, None, __env__)}'

	env['VALAPKGPATH'] = SCons.Util.CLVar('')
	env['VALAPKGPATHPREFIX'] = '--vapidir='
	env['_VALAPKGPATHS'] = '${_defines(VALAPKGPATHPREFIX, VALAPKGPATH, None, __env__)}'

	vala_compiler_action = SCons.Action.Action(
		'$VALACOM',
		'$VALACOMSTR'
	)
	vala_builder = SCons.Builder.Builder(
		action = [
			vala_compiler_action
		],
		emitter = vala_emitter,
		multi = 1,
		src_suffix = '.vala',
		suffix = '.c'
	)
	env['BUILDERS']['Vala'] = vala_builder

def exists(env):
	return env.Detect('valac')

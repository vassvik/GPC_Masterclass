package masterclass

import "core:fmt";
import "core:strings";
import gl "vendor:OpenGL";

ro2 :: proc(x: $T, mul: T) -> T {
    return mul * ((x + mul - 1) / mul)
}

swap :: proc(a, b: ^u32) { 
    a^, b^ = b^, a^
}

fmt_large_bytes :: proc(x: uint) -> string {
    u := abs(x)
    s := x < 0 ? -1 : +1

    bytes := u % 1024;
    kibibytes := (u / 1024) % 1024;
    mebibytes := (u / (1024*1024)) % 1024;
    billions := (u / (1024*1024*1024)) % 1024;

         if billions  >  0 do return fmt.tprintf("%d GiB %d MiB %d KiB %d bytes", billions, mebibytes, kibibytes, bytes)
    else if mebibytes >  0 do return fmt.tprintf("%d MiB %d KiB %d bytes",                  mebibytes, kibibytes, bytes)
    else if kibibytes >  0 do return fmt.tprintf("%d KiB %d bytes",                                    kibibytes, bytes)
    else if bytes     >= 0 do return fmt.tprintf("%d bytes",                                                      bytes)
    return ""
}

fmt_large_count :: proc(x: i32) -> string {
    u := abs(x)
    s := x < 0 ? -1 : +1

    ones := u % 1000;
    thousands := (u / 1000) % 1000;
    millions := (u / 1000000) % 1000;
    billions := (u / 1000000000) % 1000;

         if billions  >  0 do return fmt.tprintf("%s%d_%03d_%03d_%03d", s<0?"-":"", billions, millions, thousands, ones)
    else if millions  >  0 do return fmt.tprintf("%s%d_%03d_%03d", s<0?"-":"", millions, thousands, ones)
    else if thousands >  0 do return fmt.tprintf("%s%d_%03d",    s<0?"-":"", thousands, ones)
    else if ones      >= 0 do return fmt.tprintf("%s%d",       s<0?"-":"", ones)
    return ""
}

BEGIN_GL_LABEL_BLOCK :: proc(name: string) {
    gl.PushDebugGroup(gl.DEBUG_SOURCE_APPLICATION, 0, i32(len(name)), strings.unsafe_string_to_cstring(name));
}

END_GL_LABEL_BLOCK :: proc() {
    gl.PopDebugGroup();
}

@(deferred_out=END_GL_LABEL_BLOCK)
GL_LABEL_BLOCK :: proc(name: string) {
    BEGIN_GL_LABEL_BLOCK(name);
}

make_texture3D :: proc(x, y, z: i32, internal_format, format, type: u32, data: rawptr, filter: i32 = gl.NEAREST) -> u32 {
    tex: u32;
    gl.CreateTextures(gl.TEXTURE_3D, 1, &tex);
    gl.TextureParameteri(tex, gl.TEXTURE_MAG_FILTER, filter);
    gl.TextureParameteri(tex, gl.TEXTURE_MIN_FILTER, filter);
    gl.TextureParameteri(tex, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
    gl.TextureParameteri(tex, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
    gl.TextureParameteri(tex, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_BORDER);
    gl.TextureStorage3D(tex, 1, internal_format, x, y, z);
    gl.ClearTexImage(tex, 0, format, type, nil)
    if data != nil {
        gl.TextureSubImage3D(tex, 0,  0, 0, 0,  x, y, z,  format, type, data)
    }
    return tex;
}

recreate_fbo :: proc() {
    gl.DeleteTextures(1, &ctx.main_window.render_texture);
    gl.CreateTextures(gl.TEXTURE_2D, 1, &ctx.main_window.render_texture);
    gl.TextureStorage2D(ctx.main_window.render_texture, 1, gl.RGBA32F, ctx.main_window.width, ctx.main_window.height);
    gl.TextureParameteri(ctx.main_window.render_texture, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TextureParameteri(ctx.main_window.render_texture, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    gl.DeleteFramebuffers(1, &ctx.main_window.fbo);
    gl.CreateFramebuffers(1, &ctx.main_window.fbo);
    gl.NamedFramebufferTexture(ctx.main_window.fbo, gl.COLOR_ATTACHMENT0, ctx.main_window.render_texture, 0);
    assert(gl.CheckFramebufferStatus(gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE)
}

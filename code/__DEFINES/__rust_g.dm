// rust_g.dm - DM API for rust_g extension library
//
// To configure, create a `rust_g.config.dm` and set what you care about from
// the following options:
//
// #define RUST_G "path/to/rust_g"
// Override the .dll/.so detection logic with a fixed path or with detection
// logic of your own.
//
// #define RUSTG_OVERRIDE_BUILTINS
// Enable replacement rust-g functions for certain builtins. Off by default.

#ifndef RUST_G
// Default automatic RUST_G detection.
// On Windows, looks in the standard places for `rust_g.dll`.
// On Linux, looks in `.`, `$LD_LIBRARY_PATH`, and `~/.byond/bin` for either of
// `librust_g.so` (preferred) or `rust_g` (old).

/* This comment bypasses grep checks */ /var/__rust_g

/proc/__detect_rust_g()
	if (world.system_type == UNIX)
		if (fexists("./librust_g.so"))
			// No need for LD_LIBRARY_PATH badness.
			return __rust_g = "./librust_g.so"
		else if (fexists("./rust_g"))
			// Old dumb filename.
			return __rust_g = "./rust_g"
		else if (fexists("[world.GetConfig("env", "HOME")]/.byond/bin/rust_g"))
			// Old dumb filename in `~/.byond/bin`.
			return __rust_g = "rust_g"
		else
			// It's not in the current directory, so try others
			return __rust_g = "librust_g.so"
	else
		return __rust_g = "rust_g"

#define RUST_G (__rust_g || __detect_rust_g())
#endif

// Handle 515 call() -> call_ext() changes
#if DM_VERSION >= 515
#define RUSTG_CALL call_ext
#else
#define RUSTG_CALL call
#endif

/**
 * This proc generates a cellular automata noise grid which can be used in procedural generation methods.
 *
 * Returns a single string that goes row by row, with values of 1 representing an alive cell, and a value of 0 representing a dead cell.
 *
 * Arguments:
 * * percentage: The chance of a turf starting closed
 * * smoothing_iterations: The amount of iterations the cellular automata simulates before returning the results
 * * birth_limit: If the number of neighboring cells is higher than this amount, a cell is born
 * * death_limit: If the number of neighboring cells is lower than this amount, a cell dies
 * * width: The width of the grid.
 * * height: The height of the grid.
 */
#define rustg_cnoise_generate(percentage, smoothing_iterations, birth_limit, death_limit, width, height) \
	RUSTG_CALL(RUST_G, "cnoise_generate")(percentage, smoothing_iterations, birth_limit, death_limit, width, height)

#define rustg_dmi_strip_metadata(fname) RUSTG_CALL(RUST_G, "dmi_strip_metadata")(fname)
#define rustg_dmi_create_png(path, width, height, data) RUSTG_CALL(RUST_G, "dmi_create_png")(path, width, height, data)
#define rustg_dmi_resize_png(path, width, height, resizetype) RUSTG_CALL(RUST_G, "dmi_resize_png")(path, width, height, resizetype)

#define rustg_file_read(fname) RUSTG_CALL(RUST_G, "file_read")(fname)
#define rustg_file_exists(fname) RUSTG_CALL(RUST_G, "file_exists")(fname)
#define rustg_file_write(text, fname) RUSTG_CALL(RUST_G, "file_write")(text, fname)
#define rustg_file_append(text, fname) RUSTG_CALL(RUST_G, "file_append")(text, fname)
#define rustg_file_get_line_count(fname) text2num(RUSTG_CALL(RUST_G, "file_get_line_count")(fname))
#define rustg_file_seek_line(fname, line) RUSTG_CALL(RUST_G, "file_seek_line")(fname, "[line]")

#ifdef RUSTG_OVERRIDE_BUILTINS
	#define file2text(fname) rustg_file_read("[fname]")
	#define text2file(text, fname) rustg_file_append(text, "[fname]")
#endif

#define rustg_git_revparse(rev) RUSTG_CALL(RUST_G, "rg_git_revparse")(rev)
#define rustg_git_commit_date(rev) RUSTG_CALL(RUST_G, "rg_git_commit_date")(rev)

#define RUSTG_HTTP_METHOD_GET "get"
#define RUSTG_HTTP_METHOD_PUT "put"
#define RUSTG_HTTP_METHOD_DELETE "delete"
#define RUSTG_HTTP_METHOD_PATCH "patch"
#define RUSTG_HTTP_METHOD_HEAD "head"
#define RUSTG_HTTP_METHOD_POST "post"
#define rustg_http_request_blocking(method, url, body, headers, options) RUSTG_CALL(RUST_G, "http_request_blocking")(method, url, body, headers, options)
#define rustg_http_request_async(method, url, body, headers, options) RUSTG_CALL(RUST_G, "http_request_async")(method, url, body, headers, options)
#define rustg_http_check_request(req_id) RUSTG_CALL(RUST_G, "http_check_request")(req_id)

/// Generates a spritesheet at: [file_path][spritesheet_name]_[size_id].png
/// The resulting spritesheet arranges icons in a random order, with the position being denoted in the "sprites" return value.
/// All icons have the same y coordinate, and their x coordinate is equal to `icon_width * position`.
///
/// hash_icons is a boolean (0 or 1), and determines if the generator will spend time creating hashes for the output field dmi_hashes.
/// These hashes can be heplful for 'smart' caching (see rustg_iconforge_cache_valid), but require extra computation.
///
/// Spritesheet will contain all sprites listed within "sprites".
/// "sprites" format:
/// list(
///     "sprite_name" = list( // <--- this list is a [SPRITE_OBJECT]
///         icon_file = 'icons/path_to/an_icon.dmi',
///         icon_state = "some_icon_state",
///         dir = SOUTH,
///         frame = 1,
///         transform = list([TRANSFORM_OBJECT], ...)
///     ),
///     ...,
/// )
/// TRANSFORM_OBJECT format:
/// list("type" = RUSTG_ICONFORGE_BLEND_COLOR, "color" = "#ff0000", "blend_mode" = ICON_MULTIPLY)
/// list("type" = RUSTG_ICONFORGE_BLEND_ICON, "icon" = [SPRITE_OBJECT], "blend_mode" = ICON_OVERLAY)
/// list("type" = RUSTG_ICONFORGE_SCALE, "width" = 32, "height" = 32)
/// list("type" = RUSTG_ICONFORGE_CROP, "x1" = 1, "y1" = 1, "x2" = 32, "y2" = 32) // (BYOND icons index from 1,1 to the upper bound, inclusive)
///
/// Returns a SpritesheetResult as JSON, containing fields:
/// list(
///     "sizes" = list("32x32", "64x64", ...),
///     "sprites" = list("sprite_name" = list("size_id" = "32x32", "position" = 0), ...),
///     "dmi_hashes" = list("icons/path_to/an_icon.dmi" = "d6325c5b4304fb03", ...),
///     "sprites_hash" = "a2015e5ff403fb5c", // This is the xxh64 hash of the INPUT field "sprites".
///     "error" = "[A string, empty if there were no errors.]"
/// )
/// In the case of an unrecoverable panic from within Rust, this function ONLY returns a string containing the error.
#define rustg_iconforge_generate(file_path, spritesheet_name, sprites, hash_icons) RUSTG_CALL(RUST_G, "iconforge_generate")(file_path, spritesheet_name, sprites, "[hash_icons]")
/// Returns a job_id for use with rustg_iconforge_check()
#define rustg_iconforge_generate_async(file_path, spritesheet_name, sprites, hash_icons) RUSTG_CALL(RUST_G, "iconforge_generate_async")(file_path, spritesheet_name, sprites, "[hash_icons]")
/// Returns the status of an async job_id, or its result if it is completed. See RUSTG_JOB DEFINEs.
#define rustg_iconforge_check(job_id) RUSTG_CALL(RUST_G, "iconforge_check")("[job_id]")
/// Clears all cached DMIs and images, freeing up memory.
/// This should be used after spritesheets are done being generated.
#define rustg_iconforge_cleanup RUSTG_CALL(RUST_G, "iconforge_cleanup")
/// Takes in a set of hashes, generate inputs, and DMI filepaths, and compares them to determine cache validity.
/// input_hash: xxh64 hash of "sprites" from the cache.
/// dmi_hashes: xxh64 hashes of the DMIs in a spritesheet, given by `rustg_iconforge_generate` with `hash_icons` enabled. From the cache.
/// sprites: The new input that will be passed to rustg_iconforge_generate().
/// Returns a CacheResult with the following structure: list(
///     "result": "1" (if cache is valid) or "0" (if cache is invalid)
///     "fail_reason": "" (emtpy string if valid, otherwise a string containing the invalidation reason or an error with ERROR: prefixed.)
/// )
/// In the case of an unrecoverable panic from within Rust, this function ONLY returns a string containing the error.
#define rustg_iconforge_cache_valid(input_hash, dmi_hashes, sprites) RUSTG_CALL(RUST_G, "iconforge_cache_valid")(input_hash, dmi_hashes, sprites)
/// Returns a job_id for use with rustg_iconforge_check()
#define rustg_iconforge_cache_valid_async(input_hash, dmi_hashes, sprites) RUSTG_CALL(RUST_G, "iconforge_cache_valid_async")(input_hash, dmi_hashes, sprites)

#define RUSTG_ICONFORGE_BLEND_COLOR "BlendColor"
#define RUSTG_ICONFORGE_BLEND_ICON "BlendIcon"
#define RUSTG_ICONFORGE_CROP "Crop"
#define RUSTG_ICONFORGE_SCALE "Scale"

#define RUSTG_JOB_NO_RESULTS_YET "NO RESULTS YET"
#define RUSTG_JOB_NO_SUCH_JOB "NO SUCH JOB"
#define RUSTG_JOB_ERROR "JOB PANICKED"

#define rustg_json_is_valid(text) (RUSTG_CALL(RUST_G, "json_is_valid")(text) == "true")

#define rustg_log_write(fname, text, format) RUSTG_CALL(RUST_G, "log_write")(fname, text, format)
/proc/rustg_log_close_all() return RUSTG_CALL(RUST_G, "log_close_all")()

#define rustg_noise_get_at_coordinates(seed, x, y) RUSTG_CALL(RUST_G, "noise_get_at_coordinates")(seed, x, y)

#define RUSTG_REDIS_ERROR_CHANNEL "RUSTG_REDIS_ERROR_CHANNEL"

#define rustg_redis_connect(addr) RUSTG_CALL(RUST_G, "redis_connect")(addr)
/proc/rustg_redis_disconnect() return RUSTG_CALL(RUST_G, "redis_disconnect")()
#define rustg_redis_subscribe(channel) RUSTG_CALL(RUST_G, "redis_subscribe")(channel)
/proc/rustg_redis_get_messages() return RUSTG_CALL(RUST_G, "redis_get_messages")()
#define rustg_redis_publish(channel, message) RUSTG_CALL(RUST_G, "redis_publish")(channel, message)

/**
 * Takes in a string and json_encode()'d lists to produce a sanitized string.
 * This function operates on whitelists, there is currently no way to blacklist.
 * Args:
 * * text: the string to sanitize.
 * * attribute_whitelist_json: a json_encode()'d list of HTML attributes to allow in the final string.
 * * tag_whitelist_json: a json_encode()'d list of HTML tags to allow in the final string.
 */
#define rustg_sanitize_html(text, attribute_whitelist_json, tag_whitelist_json) RUSTG_CALL(RUST_G, "sanitize_html")(text, attribute_whitelist_json, tag_whitelist_json)

#define rustg_sql_connect_pool(options) RUSTG_CALL(RUST_G, "sql_connect_pool")(options)
#define rustg_sql_query_async(handle, query, params) RUSTG_CALL(RUST_G, "sql_query_async")(handle, query, params)
#define rustg_sql_query_blocking(handle, query, params) RUSTG_CALL(RUST_G, "sql_query_blocking")(handle, query, params)
#define rustg_sql_connected(handle) RUSTG_CALL(RUST_G, "sql_connected")(handle)
#define rustg_sql_disconnect_pool(handle) RUSTG_CALL(RUST_G, "sql_disconnect_pool")(handle)
#define rustg_sql_check_query(job_id) RUSTG_CALL(RUST_G, "sql_check_query")("[job_id]")

#define rustg_time_microseconds(id) text2num(RUSTG_CALL(RUST_G, "time_microseconds")(id))
#define rustg_time_milliseconds(id) text2num(RUSTG_CALL(RUST_G, "time_milliseconds")(id))
#define rustg_time_reset(id) RUSTG_CALL(RUST_G, "time_reset")(id)

/proc/rustg_unix_timestamp()
	return text2num(RUSTG_CALL(RUST_G, "unix_timestamp")())

#define rustg_raw_read_toml_file(path) json_decode(RUSTG_CALL(RUST_G, "toml_file_to_json")(path) || "null")

/proc/rustg_read_toml_file(path)
	var/list/output = rustg_raw_read_toml_file(path)
	if (output["success"])
		return json_decode(output["content"])
	else
		CRASH(output["content"])

#define rustg_raw_toml_encode(value) json_decode(RUSTG_CALL(RUST_G, "toml_encode")(json_encode(value)))

/proc/rustg_toml_encode(value)
	var/list/output = rustg_raw_toml_encode(value)
	if (output["success"])
		return output["content"]
	else
		CRASH(output["content"])

#define rustg_url_encode(text) RUSTG_CALL(RUST_G, "url_encode")("[text]")
#define rustg_url_decode(text) RUSTG_CALL(RUST_G, "url_decode")(text)

#ifdef RUSTG_OVERRIDE_BUILTINS
	#define url_encode(text) rustg_url_encode(text)
	#define url_decode(text) rustg_url_decode(text)
#endif


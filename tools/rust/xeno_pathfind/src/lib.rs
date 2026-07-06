//! Native A* grid pathfinder for NPC Xenomorph AI movement.
//!
//! This is a standalone extension (not a fork of rust-g) exposed via the same
//! `call_ext()`-compatible C ABI convention rust-g uses: fixed-arity functions
//! taking `*const c_char` string arguments and returning a `*const c_char`
//! string, valid until the next call on the same thread.
//!
//! BYOND supplies a bounded local grid (blocked/open per tile) around the
//! chase area - this does not do full-map routing, only local obstacle
//! navigation, matching the AI's existing bounded-scan philosophy.

use std::cell::RefCell;
use std::cmp::Ordering;
use std::collections::BinaryHeap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

thread_local! {
    static RETURN_STRING: RefCell<CString> = RefCell::new(CString::default());
}

/// Leaks the string into a thread-local CString and returns a pointer valid
/// until this thread's next call into this library - the standard rust-g
/// return-string pattern, since BYOND copies the string immediately.
fn return_to_byond(s: String) -> *const c_char {
    RETURN_STRING.with(|cell| {
        let cstring = CString::new(s).unwrap_or_default();
        let ptr = cstring.as_ptr();
        *cell.borrow_mut() = cstring;
        ptr
    })
}

/// # Safety
/// `ptr` must be either null or a valid pointer to a null-terminated C string,
/// which is exactly what BYOND's call_ext() passes for string arguments.
unsafe fn parse_arg<'a>(ptr: *const c_char) -> &'a str {
    if ptr.is_null() {
        return "";
    }
    CStr::from_ptr(ptr).to_str().unwrap_or("")
}

#[derive(Copy, Clone, Eq, PartialEq)]
struct OpenNode {
    priority: i32,
    x: i32,
    y: i32,
}

// BinaryHeap is a max-heap; reverse priority ordering to get a min-heap.
impl Ord for OpenNode {
    fn cmp(&self, other: &Self) -> Ordering {
        other.priority.cmp(&self.priority)
    }
}

impl PartialOrd for OpenNode {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

/// Manhattan distance heuristic - movement is 4-directional only (see
/// DIRECTIONS), so there's no diagonal cost component to approximate.
fn heuristic(x1: i32, y1: i32, x2: i32, y2: i32) -> i32 {
    let dx = (x1 - x2).abs();
    let dy = (y1 - y2).abs();
    10 * (dx + dy)
}

/// Cardinal moves only - deliberately no diagonals. Diagonal steps produced
/// the "conga line" effect when several xenos converged on the same target
/// (their near-identical diagonal shortcuts all funneled through the same
/// handful of corner tiles) and looked unnatural for a creature that isn't
/// actually cutting corners. Cardinal-only paths are longer in the open but
/// match BYOND's own cardinal movement more predictably.
const DIRECTIONS: [(i32, i32, i32); 4] = [(1, 0, 10), (-1, 0, 10), (0, 1, 10), (0, -1, 10)];

/// A* over a bounded width x height grid. `blocked[y*width+x]` is true if
/// that tile can't be entered. Returns the path from start to end inclusive,
/// or None if unreachable. Cardinal movement only (see DIRECTIONS) - no
/// diagonal steps, so there's nothing to reject for corner-cutting.
pub fn find_path(
    width: i32,
    height: i32,
    start: (i32, i32),
    end: (i32, i32),
    blocked: &[bool],
) -> Option<Vec<(i32, i32)>> {
    if width <= 0 || height <= 0 {
        return None;
    }
    let idx = |x: i32, y: i32| -> usize { (y * width + x) as usize };
    let in_bounds = |x: i32, y: i32| -> bool { x >= 0 && y >= 0 && x < width && y < height };

    if !in_bounds(start.0, start.1) || !in_bounds(end.0, end.1) {
        return None;
    }
    if blocked.len() != (width * height) as usize {
        return None;
    }
    if blocked[idx(end.0, end.1)] {
        return None;
    }
    if start == end {
        return Some(vec![start]);
    }

    let cell_count = (width * height) as usize;
    let mut g_score = vec![i32::MAX; cell_count];
    let mut came_from = vec![-1i32; cell_count];
    let mut closed = vec![false; cell_count];

    g_score[idx(start.0, start.1)] = 0;

    let mut open = BinaryHeap::new();
    open.push(OpenNode {
        priority: heuristic(start.0, start.1, end.0, end.1),
        x: start.0,
        y: start.1,
    });

    // Bounds worst-case cost - this is meant for bounded local chase-area
    // pathing (the caller passes a small grid), not full-map routing.
    let max_iterations = cell_count.saturating_mul(4);
    let mut iterations = 0usize;

    while let Some(current) = open.pop() {
        iterations += 1;
        if iterations > max_iterations {
            return None;
        }

        let cur_idx = idx(current.x, current.y);
        if closed[cur_idx] {
            continue;
        }
        if current.x == end.0 && current.y == end.1 {
            let mut path = Vec::new();
            let mut trace = cur_idx as i32;
            while trace != -1 {
                let tx = trace % width;
                let ty = trace / width;
                path.push((tx, ty));
                trace = came_from[trace as usize];
            }
            path.reverse();
            return Some(path);
        }
        closed[cur_idx] = true;

        for (dx, dy, step_cost) in DIRECTIONS.iter() {
            let nx = current.x + dx;
            let ny = current.y + dy;
            if !in_bounds(nx, ny) {
                continue;
            }
            let n_idx = idx(nx, ny);
            if closed[n_idx] || blocked[n_idx] {
                continue;
            }
            let tentative = g_score[cur_idx].saturating_add(*step_cost);
            if tentative < g_score[n_idx] {
                g_score[n_idx] = tentative;
                came_from[n_idx] = cur_idx as i32;
                let priority = tentative + heuristic(nx, ny, end.0, end.1);
                open.push(OpenNode {
                    priority,
                    x: nx,
                    y: ny,
                });
            }
        }
    }

    None
}

/// FFI entry point. `grid_desc` is "width,height,start_x,start_y,end_x,end_y"
/// (grid-local coordinates, 0-indexed). `blocked_map` is a width*height
/// length string of '0'/'1' characters, row-major. Returns a ';'-separated
/// list of "x,y" grid-local coordinates from start to end inclusive, or an
/// empty string if no path exists or the input was malformed.
///
/// # Safety
/// Called by BYOND's call_ext() with null-terminated C string arguments.
#[no_mangle]
pub extern "C" fn xeno_pathfind(
    grid_desc: *const c_char,
    blocked_map: *const c_char,
) -> *const c_char {
    let desc = unsafe { parse_arg(grid_desc) };
    let blocked_str = unsafe { parse_arg(blocked_map) };

    let parts: Vec<i32> = desc
        .split(',')
        .filter_map(|s| s.trim().parse::<i32>().ok())
        .collect();
    if parts.len() != 6 {
        return return_to_byond(String::new());
    }
    let (width, height, sx, sy, ex, ey) = (
        parts[0], parts[1], parts[2], parts[3], parts[4], parts[5],
    );

    if width <= 0 || height <= 0 || (width as i64 * height as i64) as usize != blocked_str.len() {
        return return_to_byond(String::new());
    }

    let blocked: Vec<bool> = blocked_str.bytes().map(|b| b == b'1').collect();

    match find_path(width, height, (sx, sy), (ex, ey), &blocked) {
        Some(path) => {
            let encoded: Vec<String> = path.iter().map(|(x, y)| format!("{},{}", x, y)).collect();
            return_to_byond(encoded.join(";"))
        }
        None => return_to_byond(String::new()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grid(width: i32, height: i32, blocked_coords: &[(i32, i32)]) -> Vec<bool> {
        let mut g = vec![false; (width * height) as usize];
        for (x, y) in blocked_coords {
            g[(y * width + x) as usize] = true;
        }
        g
    }

    #[test]
    fn straight_line_open_grid() {
        let b = grid(10, 10, &[]);
        let path = find_path(10, 10, (0, 0), (5, 0), &b).expect("path should exist");
        assert_eq!(path.first(), Some(&(0, 0)));
        assert_eq!(path.last(), Some(&(5, 0)));
        // Open straight line should be exactly 6 tiles (start + 5 steps), no zigzag.
        assert_eq!(path.len(), 6);
    }

    #[test]
    fn no_diagonal_steps_in_returned_path() {
        let b = grid(10, 10, &[]);
        let path = find_path(10, 10, (0, 0), (5, 5), &b).expect("path should exist");
        // Cardinal-only movement: a (5,5) offset takes 10 steps (11 tiles
        // including start), never a 5-step diagonal shortcut. Every
        // consecutive pair of tiles must differ in exactly one axis.
        assert_eq!(path.len(), 11);
        for pair in path.windows(2) {
            let (x1, y1) = pair[0];
            let (x2, y2) = pair[1];
            let dx = (x2 - x1).abs();
            let dy = (y2 - y1).abs();
            assert!(
                (dx == 1 && dy == 0) || (dx == 0 && dy == 1),
                "found a non-cardinal step: {:?} -> {:?}",
                pair[0],
                pair[1]
            );
        }
    }

    #[test]
    fn routes_around_a_wall_with_a_gap() {
        // Vertical wall at x=5 spanning y=0..8, with a gap at y=9.
        let mut blocked_coords = vec![];
        for y in 0..9 {
            blocked_coords.push((5, y));
        }
        let b = grid(10, 10, &blocked_coords);
        let path = find_path(10, 10, (0, 0), (9, 0), &b).expect("path should exist through the gap");
        // Must pass through the only gap in the wall.
        assert!(path.contains(&(5, 9)));
    }

    #[test]
    fn unreachable_target_returns_none() {
        // Fully enclose the target at (5,5) with a ring of blocked tiles.
        let mut blocked_coords = vec![];
        for x in 4..=6 {
            for y in 4..=6 {
                if !(x == 5 && y == 5) {
                    blocked_coords.push((x, y));
                }
            }
        }
        let b = grid(10, 10, &blocked_coords);
        assert!(find_path(10, 10, (0, 0), (5, 5), &b).is_none());
    }

    #[test]
    fn blocked_start_or_end_out_of_bounds_is_handled_gracefully() {
        let b = grid(5, 5, &[]);
        assert!(find_path(5, 5, (-1, 0), (2, 2), &b).is_none());
        assert!(find_path(5, 5, (0, 0), (10, 10), &b).is_none());
    }

    #[test]
    fn ffi_roundtrip_produces_expected_path_string() {
        let grid_desc = CString::new("5,5,0,0,4,0").unwrap();
        let blocked_map = CString::new("0".repeat(25)).unwrap();
        let result_ptr = xeno_pathfind(grid_desc.as_ptr(), blocked_map.as_ptr());
        let result = unsafe { CStr::from_ptr(result_ptr) }.to_str().unwrap();
        assert_eq!(result, "0,0;1,0;2,0;3,0;4,0");
    }

    #[test]
    fn ffi_malformed_input_returns_empty_string_not_a_crash() {
        let grid_desc = CString::new("not,a,valid,grid").unwrap();
        let blocked_map = CString::new("").unwrap();
        let result_ptr = xeno_pathfind(grid_desc.as_ptr(), blocked_map.as_ptr());
        let result = unsafe { CStr::from_ptr(result_ptr) }.to_str().unwrap();
        assert_eq!(result, "");
    }
}

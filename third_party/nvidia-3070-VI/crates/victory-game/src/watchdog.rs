//! The title's hang watchdog: how long it waits for progress.
//!
//! A thread of the title wakes about once a second. When none of its
//! threads has a watched wait open, it compares a progress stamp that the
//! title's update loops write at the start of each pass with the one it saw
//! last; after 30 checks in a row without a change it stops the title on
//! purpose (a store to address 0 with an error code). On the console a
//! pass that takes 30 s is a hang. Here loading is many times slower (new
//! card memory waited for while the card is near its budget, title memory
//! copied for the card), and runs were stopped while frames still came.
//!
//! [`patience_sites`] finds that function by a short byte signature and
//! the eight places that load the count of 30, so that the runtime can give
//! the watchdog more checks (`VICTORY_WATCHDOG_SECONDS`). A real hang is
//! still stopped, later. The per-thread check of watched waits (300 s) is
//! not touched.

/// The bytes at the start of the watchdog's loop setup in the known build:
/// `mov r15d, 0x0fffffff; mov ebp, 30; test rsi, rsi`.
const SIGNATURE: [u8; 14] = [
    0x41, 0xbf, 0xff, 0xff, 0xff, 0x0f, 0xbd, 0x1e, 0x00, 0x00, 0x00, 0x48, 0x85, 0xf6,
];

/// How far past the signature the function's loads of 30 lie (its end is
/// about 0x2b0 bytes on).
const WINDOW: usize = 0x300;

/// The count of checks the title loads (30, about a second each).
pub const TITLE_CHECKS: u8 = 30;

/// Offsets, in `image`, of the immediate byte of every `mov ebp, 30` and
/// `mov ebx, 30` in the watchdog function, if its signature is found
/// exactly once; `None` otherwise (another build: nothing is changed).
pub fn patience_sites(image: &[u8]) -> Option<Vec<usize>> {
    let mut found = memchr::memmem::find_iter(image, &SIGNATURE);
    let at = found.next()?;
    if found.next().is_some() {
        return None;
    }
    let end = (at + WINDOW).min(image.len());
    let window = &image[at..end];
    let mut sites = Vec::new();
    for (i, w) in window.windows(5).enumerate() {
        if matches!(w[0], 0xbd | 0xbb) && w[1] == TITLE_CHECKS && w[2..5] == [0, 0, 0] {
            sites.push(at + i + 1);
        }
    }
    // The known build has eight; anything else is not the function we know.
    (sites.len() == 8).then_some(sites)
}

/// The count of checks for `seconds` (`VICTORY_WATCHDOG_SECONDS`): at
/// least the title's own 30, at most 255; `None` to leave it as it is.
pub fn checks_for(seconds: &str) -> Option<u8> {
    let n: u32 = seconds.trim().parse().ok()?;
    (n > u32::from(TITLE_CHECKS)).then(|| n.min(255) as u8)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn function() -> Vec<u8> {
        let mut f = vec![0x90u8; 0x320];
        f[0x40..0x40 + SIGNATURE.len()].copy_from_slice(&SIGNATURE);
        // Seven more loads of 30 after the signature's own.
        for (k, op) in [0xbd, 0xbd, 0xbd, 0xbd, 0xbd, 0xbd, 0xbb].iter().enumerate() {
            let at = 0x80 + k * 0x30;
            f[at..at + 5].copy_from_slice(&[*op, 30, 0, 0, 0]);
        }
        f
    }

    #[test]
    fn the_eight_loads_of_thirty_are_found() {
        let f = function();
        let sites = patience_sites(&f).expect("found");
        assert_eq!(sites.len(), 8);
        assert_eq!(sites[0], 0x40 + 7);
        assert!(sites.iter().all(|&s| f[s] == 30));
    }

    #[test]
    fn nothing_without_one_signature_or_with_another_count() {
        let f = function();
        assert!(patience_sites(&f[0x50..]).is_none(), "no signature");
        let mut twice = f.clone();
        twice.extend_from_slice(&f);
        assert!(patience_sites(&twice).is_none(), "two signatures");
        let mut fewer = f.clone();
        fewer[0x80] = 0x90;
        assert!(patience_sites(&fewer).is_none(), "seven loads");
    }

    #[test]
    fn seconds_become_checks() {
        assert_eq!(checks_for("120"), Some(120));
        assert_eq!(checks_for("30"), None);
        assert_eq!(checks_for("10"), None);
        assert_eq!(checks_for("1000"), Some(255));
        assert_eq!(checks_for("x"), None);
    }
}

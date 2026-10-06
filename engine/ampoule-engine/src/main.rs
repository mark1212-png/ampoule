//! ampoule-engine: Ampoule's VM engine on Hypervisor.framework (decisions 0006, 0014).
//!
//! Placeholder until milestone E1 (boot a Linux kernel to a serial console).

use std::process::ExitCode;

fn version_line() -> String {
    format!("ampoule-engine {}", env!("CARGO_PKG_VERSION"))
}

fn main() -> ExitCode {
    if std::env::args().skip(1).any(|arg| arg == "--version") {
        println!("{}", version_line());
        return ExitCode::SUCCESS;
    }
    eprintln!("ampoule-engine: not implemented yet (milestone E1)");
    ExitCode::FAILURE
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_line_names_the_binary() {
        assert!(version_line().starts_with("ampoule-engine "));
    }
}

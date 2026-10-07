// Empêche la console qui s'ouvre en plus sur Windows en mode release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    gamedraw_lib::run();
}

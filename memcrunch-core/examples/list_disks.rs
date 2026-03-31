fn main() {
    let disks = sysinfo::Disks::new_with_refreshed_list();
    for d in disks.list() {
        println!(
            "{:30} {:10} {:>12} removable={} ro={}",
            d.mount_point().to_string_lossy(),
            d.file_system().to_string_lossy(),
            d.total_space(),
            d.is_removable(),
            d.is_read_only()
        );
    }
}

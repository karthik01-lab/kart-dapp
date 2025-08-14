module iot_dapp::verisense {
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_framework::table::{Self, Table};
    
    
    
    use std::vector;
    use aptos_framework::signer;
    use std::option;

    // Errors
    const E_SENSOR_ALREADY_REGISTERED: u64 = 1;
    const E_SENSOR_NOT_FOUND: u64 = 2;
    const E_UNAUTHORIZED: u64 = 3;
    const E_INVALID_RULE: u64 = 4;
    const E_RULE_NOT_FOUND: u64 = 5;
    const E_ACTUATOR_NOT_FOUND: u64 = 6;

    // Structs
    struct Device has key, store, copy {
        owner: address,
        device_type: vector<u8>, // "sensor" or "actuator"
        name: vector<u8>,
        location: vector<u8>,
        is_public: bool,
        // In a real scenario, this would link to an NFT object
        nft_id: u64, // Placeholder for NFT ID
        latest_data_id: u64, // ID of the latest attested data for sensors
    }

    struct SensorData has key, store {
        device_id: u64,
        timestamp_ms: u64,
        value: vector<u8>, // Data value (e.g., "25C, 60%RH")
    }

    struct Rule has key, store {
        owner: address,
        trigger_sensor_id: u64,
        target_actuator_id: u64,
        condition: vector<u8>, // e.g., ">", "<", "=="
        value: vector<u8>,
        action: vector<u8>, // e.g., "on", "off"
    }

    // Events
    struct DeviceRegisteredEvent has drop, store {
        device_id: u64,
        owner: address,
        device_type: vector<u8>,
        name: vector<u8>,
    }

    struct DataAttestedEvent has drop, store {
        device_id: u64,
        timestamp_ms: u64,
        value: vector<u8>,
    }

    struct ActionExecutedEvent has drop, store {
        actuator_id: u64,
        action: vector<u8>,
        triggered_by_rule_id: option::Option<u64>,
    }

    struct Verisense has key {
    next_device_id: u64,
    devices: Table<u64, Device>,
    sensor_data: Table<u64, SensorData>,
    rules: Table<u64, Rule>,
    rule_ids: vector<u64>,
    next_data_id: u64,
    next_rule_id: u64,
    device_registered_events: event::EventHandle<DeviceRegisteredEvent>,
    data_attested_events: event::EventHandle<DataAttestedEvent>,
    action_executed_events: event::EventHandle<ActionExecutedEvent>,
}


    fun init_module(sender: &signer) {
        // Only allow initialization once
        assert!(!exists<Verisense>(@iot_dapp), 0);

                let device_registered_events_handle = account::new_event_handle<DeviceRegisteredEvent>(sender);
        let data_attested_events_handle = account::new_event_handle<DataAttestedEvent>(sender);
        let action_executed_events_handle = account::new_event_handle<ActionExecutedEvent>(sender);

        move_to(sender, Verisense {
            next_device_id: 0,
            devices: table::new(),
            sensor_data: table::new(),
            rules: table::new(),
            rule_ids: vector::empty(),
            next_data_id: 0,
            next_rule_id: 0,
            device_registered_events: device_registered_events_handle,
            data_attested_events: data_attested_events_handle,
            action_executed_events: action_executed_events_handle,
        });
    }

    public entry fun register_device(
        sender: &signer,
        device_type: vector<u8>,
        name: vector<u8>,
        location: vector<u8>,
    ) acquires Verisense {
        let verisense = borrow_global_mut<Verisense>(@iot_dapp);

        let device_id = verisense.next_device_id;
        verisense.next_device_id += 1;

        let new_device = Device {
            owner: signer::address_of(sender),
            device_type,
            name,
            location,
            is_public: false,
            nft_id: device_id, // Placeholder for actual NFT minting
            latest_data_id: 0, // No data attested yet
        };

        let event_device_type = new_device.device_type;
        let event_name = new_device.name;

        verisense.devices.add(device_id, new_device);

        event::emit_event(&mut verisense.device_registered_events, DeviceRegisteredEvent {
            device_id,
            owner: signer::address_of(sender),
            device_type: event_device_type,
            name: event_name,
        });
    }

    #[view]
    public fun get_device(device_id: u64): Device acquires Verisense {  
        let verisense = borrow_global<Verisense>(@iot_dapp);
        assert!(verisense.devices.contains(device_id), E_SENSOR_NOT_FOUND);
        let device = *verisense.devices.borrow(device_id);
        device
    }

     #[view]
    public fun get_devices(): vector<Device> acquires Verisense {  
        let verisense = borrow_global<Verisense>(@iot_dapp);
        let ndevices = verisense.next_device_id;
        let devices = vector::empty<Device>();
        let i = 0;
        while (i < ndevices) {
            if (verisense.devices.contains(i)) {
                let device = verisense.devices.borrow(i);
                devices.push_back(*device);
            };
            i += 1;
        };
        devices
    }

    public entry fun attest_data(
        sender: &signer,
        device_id: u64,
        value: vector<u8>,
    ) acquires Verisense {
        let verisense = borrow_global_mut<Verisense>(@iot_dapp);

        assert!(table::contains(&verisense.devices, device_id), E_SENSOR_NOT_FOUND);

        let sensor = table::borrow_mut(&mut verisense.devices, device_id);
        assert!(sensor.owner == signer::address_of(sender), E_UNAUTHORIZED);

        let data_id = verisense.next_data_id;
        verisense.next_data_id = verisense.next_data_id + 1;

        let new_data = SensorData {
            device_id,
            timestamp_ms: timestamp::now_microseconds(),
            value,
        };

        let event_timestamp_ms = new_data.timestamp_ms;
        let event_value = new_data.value;

        table::add(&mut verisense.sensor_data, data_id, new_data);
        sensor.latest_data_id = data_id;

        event::emit_event(&mut verisense.data_attested_events, DataAttestedEvent {
            device_id,
            timestamp_ms: event_timestamp_ms,
            value: event_value,
        });

        // Check rules
        // Note: This is a simplified check. A real implementation would need a more robust parser.
        let rules_to_trigger = vector::empty<u64>();
        // let i = 0;
        // loop {
        //     if (i >= vector::length(&verisense.rule_ids)) break;
        //     let rule_id = *vector::borrow(&verisense.rule_ids, i);
        //     let rule = table::borrow(&verisense.rules, rule_id);
        //     if (rule.trigger_sensor_id == device_id) {
        //         // Simple check: if new value equals rule value
        //         if (rule.value == new_data.value) {
        //             vector::push_back(&mut rules_to_trigger, rule_id);
        //         }
        //     }
        //     std::debug::print(&i);
        // };

        let i = 0;
        loop {
            if (i >= vector::length(&rules_to_trigger)) break;
            let rule_id = *vector::borrow(&rules_to_trigger, i);
            let rule = table::borrow(&verisense.rules, rule_id);
            event::emit_event(&mut verisense.action_executed_events, ActionExecutedEvent {
                actuator_id: rule.target_actuator_id,
                action: rule.action,
                triggered_by_rule_id: option::some(rule_id),
            });
            std::debug::print(&i);
        };
    }

    public entry fun add_rule(
        sender: &signer,
        trigger_sensor_id: u64,
        target_actuator_id: u64,
        condition: vector<u8>,
        value: vector<u8>,
        action: vector<u8>,
    ) acquires Verisense {
        let verisense = borrow_global_mut<Verisense>(@iot_dapp);
        let owner = signer::address_of(sender);

        // Verify owner owns both devices
        assert!(table::contains(&verisense.devices, trigger_sensor_id), E_SENSOR_NOT_FOUND);
        assert!(table::contains(&verisense.devices, target_actuator_id), E_ACTUATOR_NOT_FOUND);

        let trigger_sensor = table::borrow(&verisense.devices, trigger_sensor_id);
        let target_actuator = table::borrow(&verisense.devices, target_actuator_id);

        assert!(trigger_sensor.owner == owner, E_UNAUTHORIZED);
        assert!(target_actuator.owner == owner, E_UNAUTHORIZED);

        let rule_id = verisense.next_rule_id;
        verisense.next_rule_id = verisense.next_rule_id + 1;

        let new_rule = Rule {
            owner,
            trigger_sensor_id,
            target_actuator_id,
            condition,
            value,
            action,
        };

        table::add(&mut verisense.rules, rule_id, new_rule);
        vector::push_back(&mut verisense.rule_ids, rule_id);
    }

    public entry fun execute_manual_action(
        sender: &signer,
        actuator_id: u64,
        action: vector<u8>,
    ) acquires Verisense {
        let verisense = borrow_global_mut<Verisense>(@iot_dapp);
        let owner = signer::address_of(sender);

        assert!(table::contains(&verisense.devices, actuator_id), E_ACTUATOR_NOT_FOUND);
        let actuator = table::borrow(&verisense.devices, actuator_id);
        assert!(actuator.owner == owner, E_UNAUTHORIZED);

        event::emit_event(&mut verisense.action_executed_events, ActionExecutedEvent {
            actuator_id,
            action,
            triggered_by_rule_id: option::none(),
        });
    }

    public entry fun set_public(
        sender: &signer,
        device_id: u64,
        is_public: bool,
    ) acquires Verisense {
        let verisense = borrow_global_mut<Verisense>(@iot_dapp);

        assert!(table::contains(&verisense.devices, device_id), E_SENSOR_NOT_FOUND);

        let device = table::borrow_mut(&mut verisense.devices, device_id);
        assert!(device.owner == signer::address_of(sender), E_UNAUTHORIZED);

        device.is_public = is_public;
    }

    public fun get_latest_data(device_id: u64): (u64, u64, vector<u8>) acquires Verisense {
        let verisense = borrow_global<Verisense>(@iot_dapp);
        assert!(table::contains(&verisense.devices, device_id), E_SENSOR_NOT_FOUND);

        let sensor = table::borrow(&verisense.devices, device_id);
        assert!(sensor.latest_data_id != 0, E_SENSOR_NOT_FOUND); // No data attested yet

        let data = table::borrow(&verisense.sensor_data, sensor.latest_data_id);
        (data.device_id, data.timestamp_ms, data.value)
    }

    public fun get_device_metadata(device_id: u64): (address, vector<u8>, vector<u8>, vector<u8>, u64) acquires Verisense {
        let verisense = borrow_global<Verisense>(@iot_dapp);
        assert!(table::contains(&verisense.devices, device_id), E_SENSOR_NOT_FOUND);

        let device = table::borrow(&verisense.devices, device_id);
        (device.owner, device.device_type, device.name, device.location, device.nft_id)
    }
}
<p align="center">
<img src="https://github.com/DimaRU/TridentCockpit/raw/master/TridentCockpit/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" />
</p>

<p align="center">TridentCockpit is an unofficial macOS control app for the <a href="https://www.sofarocean.com/products/trident">Sofar Trident Underwater Drone</a>.</p>

<p align=center>
 ·
<a href="https://github.com/DimaRU/TridentCockpit/releases">Releases</a> ·

</p>

---

## Features

* Controls the Trident Underwater Drone by Sofar Ocean
* Watch video stream from the drone
* Keyboard, mouse and gamepad control 
* Controls camera, light, stabilization
* Realtime drone orientation view
* View depth, temperature, camera and battery times

## Supported gamepads

* Xbox Wireless Controller
* DualShock 4
* MFi gamepad

## Keyboard Shortcuts

### Moton control

| Shortcut | Description |
|:-:|:-:|
| <kbd>Up Arrow</kbd> | Forward |
| <kbd>Down Arrow</kbd> | Backward |
| <kbd>Left Arrow</kbd> | Turn Left (rotate counterclockwise) |
| <kbd>Right Arrow</kbd> | Turn Right (rotate clockwise) |
| <kbd>W</kbd> | Tilt Down |
| <kbd>E</kbd> | Tilt Up |

### Motor speed modifiers
| Shortcut | Description |
|:-:|:-:|
| without modifiers | 10% of motor speed |
|&#8997;<kbd>Option</kbd> + (<kbd>&uarr;</kbd> &#124; <kbd>&darr;</kbd> &#124; <kbd>&larr;</kbd> &#124; <kbd>&rarr;</kbd> &#124; <kbd>W</kbd> &#124; <kbd>E</kbd>)| 25% of motor speed |
|&#8963;<kbd>Control</kbd> + (<kbd>&uarr;</kbd> &#124; <kbd>&darr;</kbd> &#124; <kbd>&larr;</kbd> &#124; <kbd>&rarr;</kbd> &#124; <kbd>W</kbd> &#124; <kbd>E</kbd>)| 50% of motor speed |
|&#8679;<kbd>Shift</kbd> + (<kbd>&uarr;</kbd> &#124; <kbd>&darr;</kbd> &#124; <kbd>&larr;</kbd> &#124; <kbd>&rarr;</kbd> &#124; <kbd>W</kbd> &#124; <kbd>E</kbd>)| 100% of motor speed |

### Other shortcuts
| Shortcut | Description |
|:-:|:-:|
| <kbd>L</kbd> | Light control |
| <kbd>R</kbd> | Camera control |
| <kbd>Y</kbd> | Drone view relative yaw |
| <kbd>A</kbd> | Drone view absolute yaw |

## Building from Source

These instructions will get you a copy of the project up and running on your local machine for development purposes.

### Required software

* CMake

1. Install Xcode from App Store
2. Install build tools by running `brew install cmake`




### Build

* Run from the terminal:

```
git clone --recurse-submodules https://github.com/DimaRU/TridentCockpit.git
cd TridentCockpit
```

* Open TridentCockpit.xcodeproj in the [latest public version of Xcode](https://itunes.apple.com/us/app/xcode/id497799835). *TridentCockpit may not build if you use any other version.*
* Change the Team to your own team in the "Signing & Capabilities" panel.
* Ensure that the scheme is set to TridentCockpit.
* Build the project.


## Dependencies

* [Eprosima Fast RTPS](https://github.com/eProsima/Fast-RTPS) -  implementation of the OMG RTPS protocol
* [Foonathan memory](https://github.com/foonathan/memory) - Fast RTPS dependency
* [FlatButton](https://github.com/OskarGroth/FlatButton) - Layer based NSButton with Interface Builder styling options
* [FastRTPSBridge](https://github.com/DimaRU/FastRTPSBridge) - A Swift wrapper for FastRTPS library
* [CDRCodable](https://github.com/DimaRU/CDRCodable) - Zero code serialization/deserialization framework for Common Data Representation (CDR) binary format


## Author

* **Dmitriy Borovikov** - [DimaRU](https://github.com/DimaRU), AOWD diver, iOS developer, Openrov Tdident Kickstarter backer #1284

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Credits

* Thanks to Jim N. for "Software Exploration - DDS and the Trident" series of posts on [Openrov forum](https://forum.openrov.com/t/software-exploration-dds-and-the-trident-5-fastrtps/7277)

## Disclaimer

This project is unofficial (meaning not supported by or affiliated with Sofar Ocean). Use it at your own risk.

# SunSync API Home Assistant Integration

**Forked and Enhanced by:** [Julian Jones](github.com/jujo1)
**Original Author:** [Martin Ville](github.com/martinville)

## Overview

SunSync is a Home Assistant integration designed to connect to the SunSynk ((github.com/martinville
) API, fetching solar system data to dynamically create and update sensor entities
within Home Assistant.

## Why This Fork?

This fork by jujo1 enhances the original integration with:

- Improved error handling and robust retry mechanisms for API calls
- Dynamic creation of Home Assistant entities
- Enhanced code structure and readability
- Adoption of improved bash scripting practices

## How SunSync Works

SunSync obtains solar system data from the SunSynk cloud API, originally uploaded by your inverter via the SunSynk dongle. It has no direct physical interface
with your inverter hardware.

**Please note:** This integration only populates sensor data and does not include display cards.

This integration specifically targets **SunSynk Region 2** and supports setups with multiple inverters.

## Documentation

For detailed instructions, see [DOCS.md](github.com/jujo1/SunSync/blob/main/DOCS.md).

## Version Management

This repository uses git tags for version management. The version in `config.yaml` is automatically updated based on the highest semantic version tag available.

### For Contributors

1. After cloning this repository, run `./setup-hooks.sh` to install the git hooks
2. When a new version is ready for release, create and push a new tag following semantic versioning:

```bash
git tag v1.2.3
git push origin v1.2.3
```

3. When you pull changes that include new tags, the version in `config.yaml` will automatically update

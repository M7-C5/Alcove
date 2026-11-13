# ADR-0005: Capture room north for the lighting preview

Status: Accepted

Date: 2026-11-13

## Context

Lighting needs a north reference that belongs to the room, rather than the current
camera viewpoint. Existing saved rooms and sample rooms have no compass data.
The current `RoomScanSheet` is a manual form that creates sample furniture; it does
not yet run a RoomPlan capture session. AR walkthrough and the main viewport are
outside this change's scope.

## Decision

- Use Core Motion's `xMagneticNorthZVertical` reference frame while the scan screen
  is active. Project the rear camera's forward axis onto the horizontal plane;
  this does not depend on portrait or landscape interface orientation.
- In the current manual scan, the initial camera direction defines the room's
  forward (-Z) axis. The scan screen tells the person to face the front of the room.
  Require medium/high calibration and three readings within 3 degrees before
  freezing the circular mean. Reject a camera pointing almost vertically.
- Stop sensor updates after capture, dismissal, or app inactivity. Ignore callbacks
  from earlier capture generations. Do not request location or background tracking.
- Persist an optional Codable `RoomCompassOrientation` payload on `Room` so a
  layout reset does not erase orientation. Missing/corrupt data remains unknown;
  old and sample rooms retain the previous sample-direction preview.
- Rotate the educational east–south–west sunlight arc into room coordinates. This
  is magnetic north alignment, not a geographic solar calculation: no latitude,
  longitude, date, magnetic declination, or window-specific irradiance is modeled.
- Read camera preset angles from the existing `ViewportPreset` used by the primary
  viewport. Do not change AR walkthrough or its camera/session configuration.

## Consequences and future scan integration

The preview can now respect a room's captured magnetic orientation, independently
of viewing angle. Physical compass capture must be verified on a sensor-equipped
iPad; simulator tests cover direction math, filtering, persistence and camera
invariance, not magnetometer accuracy.

When a real RoomPlan scanner is added, it must supply the bearing of its **final
normalized model's -Z axis**. It must account for the camera transform at capture
start and any model rotation applied on import. Reusing the manual scan's initial
camera bearing without that transform would misalign north.

## Device checks

1. Open New Room Scan with iPad upright facing a known wall; wait for North captured.
2. Save, reopen the room, and confirm the north-alignment label in lighting.
3. Check morning/evening light against the captured room bearing; rotate all camera
   presets and confirm that the sunlight stays fixed relative to the room.
4. Cancel or background a scan, resume, and verify sensor capture stops/restarts.
5. Test with a flat iPad and poor magnetic calibration: no invented orientation
   should be saved, and saving without a compass fix must remain possible.

## References

- [Apple: Magnetic north reference frame](https://developer.apple.com/documentation/coremotion/cmattitudereferenceframe/xmagneticnorthzvertical)
- [Apple: Processed device-motion data](https://developer.apple.com/documentation/coremotion/getting-processed-device-motion-data)

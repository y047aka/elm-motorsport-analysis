# Elm-Rust CLI JSON Compatibility Analysis - TODO Implementation List

## Summary

This document outlines the specific differences identified between the Elm CLI and Rust CLI JSON outputs through comprehensive integration testing. These test cases follow TDD methodology to drive implementation improvements.

**Progress Tracking**: ❌ Not Started | 🔄 In Progress | ✅ Completed | 🧪 Testing Required

## TODO: Implementation Tasks

### 🔥 High Priority (Breaking Changes)

#### 1. Event Name Mapping Fix ❌
- [ ] **Task**: Fix `map_event_name("imola_6h")` to return "6 Hours of Imola"
- **Issue**: Event name "imola_6h" maps to "Encoding Error" instead of "6 Hours of Imola"
- **Expected**: `"name": "6 Hours of Imola"`
- **Actual**: `"name": "Encoding Error"`
- **Test Case**: `test_event_name_mapping_issue` (currently fails)
- **Files to modify**: `src/lib.rs` - `map_event_name()` function
- **Acceptance Criteria**: 
  - [ ] `map_event_name("imola_6h")` returns "6 Hours of Imola"
  - [ ] Test `test_event_name_mapping_issue` passes
  - [ ] Test `test_real_wec_imola_data_elm_compatibility` passes

#### 2. Numeric Precision Fix ❌
- [ ] **Task**: Round KPH values to match Elm precision (1 decimal place)
- **Issue**: KPH values have excessive floating-point precision
- **Expected**: `"kph": 164.6`
- **Actual**: `"kph": 164.60000610351563`
- **Test Case**: `test_kph_precision_issue` (currently fails)
- **Files to modify**: Data parsing or serialization logic for KPH values
- **Acceptance Criteria**:
  - [ ] KPH values rounded to 1 decimal place
  - [ ] Test `test_kph_precision_issue` passes
  - [ ] Test `test_specific_lap_data_accuracy` passes
  - [ ] All numeric precision tests pass

### 📋 Medium Priority (Quality of Life)

#### 3. JSON Field Ordering Consistency ❌
- [ ] **Task**: Ensure consistent alphabetical field ordering in JSON output
- **Issue**: JSON fields are not in consistent alphabetical order
- **Expected**: Fields in alphabetical order (crossingFinishLineInPit before driverName)
- **Actual**: Fields appear in struct definition order
- **Test Case**: `test_json_field_ordering_issue` (currently fails)
- **Files to modify**: Serialization structs or custom serializer
- **Acceptance Criteria**:
  - [ ] JSON fields appear in alphabetical order
  - [ ] Test `test_json_field_ordering_issue` passes
  - [ ] Test `test_field_ordering_consistency` passes

### 🔍 Low Priority (Nice to Have)

#### 4. Sector Time Precision Verification ❌
- [ ] **Task**: Verify all sector time fields have consistent precision
- **Test Case**: `test_sector_time_precision_issue`
- **Files to check**: Sector time parsing and formatting
- **Acceptance Criteria**:
  - [ ] Sector times match Elm output exactly
  - [ ] No trailing precision artifacts

### ✅ Verified Compatibility (Already Working)

#### Structure Compatibility ✅
- [x] Top-level structure matches: `name`, `laps`, `preprocessed` fields present
- [x] All required lap fields present with correct data types
- [x] Preprocessed car data structure matches Elm expectations

#### Data Type Compatibility ✅
- [x] String fields are correctly string type (not null)
- [x] Numeric fields have correct types (integers vs floats)
- [x] Empty optional fields are empty strings (not null) as expected by Elm

#### Content Accuracy ✅
- [x] Lap times, sector times, and elapsed times match exactly
- [x] Driver names, team names, and manufacturers match
- [x] Improvement flags (0, 1, 2) work correctly
- [x] Pit stop data (crossingFinishLineInPit, pitTime) handles correctly

#### Edge Cases ✅
- [x] Very slow lap times (pit stops) handle correctly
- [x] Long sector times (pit lane) format properly
- [x] Safety car periods and race control scenarios work

## Verified Compatibility ✅

### Structure Compatibility
- Top-level structure matches: `name`, `laps`, `preprocessed` fields present
- All required lap fields present with correct data types
- Preprocessed car data structure matches Elm expectations

### Data Type Compatibility
- String fields are correctly string type (not null)
- Numeric fields have correct types (integers vs floats)
- Empty optional fields are empty strings (not null) as expected by Elm

### Content Accuracy
- Lap times, sector times, and elapsed times match exactly
- Driver names, team names, and manufacturers match
- Improvement flags (0, 1, 2) work correctly
- Pit stop data (crossingFinishLineInPit, pitTime) handles correctly

### Edge Cases
- Very slow lap times (pit stops) handle correctly
- Long sector times (pit lane) format properly
- Safety car periods and race control scenarios work

## Test Case Coverage

### Comprehensive Integration Tests Added:
1. `test_elm_vs_rust_json_structure_comparison` - Top-level structure
2. `test_lap_field_data_types_compatibility` - Data type verification
3. `test_improvement_flags_compatibility` - Improvement flag handling
4. `test_pit_stop_data_compatibility` - Pit stop scenarios
5. `test_empty_string_vs_null_compatibility` - Null vs empty string handling
6. `test_real_wec_imola_data_elm_compatibility` - Real data compatibility
7. `test_specific_lap_data_accuracy` - Exact value matching
8. `test_edge_case_lap_times_and_sectors` - Edge case handling
9. `test_numeric_precision_consistency` - Numeric precision verification
10. `test_string_formatting_consistency` - String format verification
11. `test_field_ordering_consistency` - JSON field ordering

### TDD Failing Test Cases (Implementation Targets):
1. `test_event_name_mapping_issue` - Event name mapping fix
2. `test_kph_precision_issue` - Numeric precision fix  
3. `test_json_field_ordering_issue` - Field ordering fix
4. `test_sector_time_precision_issue` - Sector time precision verification

## 📋 Implementation Workflow

### Step-by-Step Implementation Guide

#### Phase 1: Critical Fixes (Required for Elm compatibility) 🔥
1. [ ] **Start with Event Name Mapping**
   - Run `cargo test test_event_name_mapping_issue -- --nocapture` to confirm failure
   - Fix `map_event_name()` function in `src/lib.rs`
   - Verify fix with `cargo test test_real_wec_imola_data_elm_compatibility`

2. [ ] **Fix Numeric Precision**
   - Run `cargo test test_kph_precision_issue -- --nocapture` to confirm failure
   - Implement KPH rounding to 1 decimal place
   - Verify with `cargo test test_specific_lap_data_accuracy`

#### Phase 2: Quality Improvements (Nice to have) 📋
3. [ ] **JSON Field Ordering**
   - Run `cargo test test_json_field_ordering_issue -- --nocapture`
   - Implement consistent field ordering
   - Verify with full integration test suite

#### Phase 3: Verification (Final validation) 🧪
4. [ ] **Run Full Test Suite**
   - Execute `cargo test -- --nocapture`
   - Verify all compatibility tests pass
   - Document any remaining differences

### Progress Tracking Template

Copy this section and update as you implement:

```markdown
## 🚀 Current Implementation Status

### High Priority Tasks
- [ ] Event Name Mapping Fix - **Status**: ❌ Not Started
- [ ] Numeric Precision Fix - **Status**: ❌ Not Started

### Medium Priority Tasks  
- [ ] JSON Field Ordering - **Status**: ❌ Not Started

### Testing Status
- [ ] All integration tests passing - **Status**: ❌ Not Started

### Notes
- Started: [Date]
- Last Updated: [Date]
- Current Focus: [Task Name]
- Blockers: [Any issues]
```

## 🔧 Quick Reference Commands

### Validation Commands
```bash
# Run all integration tests
cargo test -- --nocapture

# Run specific failing tests (implementation targets)
cargo test test_event_name_mapping_issue -- --nocapture
cargo test test_kph_precision_issue -- --nocapture  
cargo test test_json_field_ordering_issue -- --nocapture

# Run specific compatibility validation tests
cargo test test_real_wec_imola_data_elm_compatibility -- --nocapture
cargo test test_specific_lap_data_accuracy -- --nocapture

# Generate comparison output for manual inspection
cargo test test_missing_features_comparison -- --nocapture
```

### Development Commands
```bash
# Build and test cycle
cargo build --release
cargo test -- --nocapture

# Run CLI to generate test output
cargo run --release -- ../../app/static/wec/2025/imola_6h.csv test_output.json imola_6h
```

## 📁 Files in This Implementation

- ✅ `/cli/cli/tests/integration.rs` - Comprehensive test suite (18 tests)
- ✅ `/cli/cli/tests/TDD_DIFFERENCES_SUMMARY.md` - This TODO implementation guide  
- 📋 `/cli/cli/test_missing_features.json` - Generated comparison output
- 🔧 `/cli/cli/src/lib.rs` - **TARGET**: Event name mapping function
- 🔧 `/cli/cli/src/preprocess.rs` - **TARGET**: Data processing and serialization

## 🎯 Success Criteria

**Implementation is complete when:**
- [ ] All 18 integration tests pass
- [ ] Rust CLI output matches Elm CLI output structure exactly
- [ ] JSON comparison between Elm and Rust outputs shows no differences
- [ ] Real WEC data processes correctly with proper event names

**Ready for production when:**
- [ ] All tests pass consistently
- [ ] Performance benchmarks meet requirements  
- [ ] Code review completed
- [ ] Documentation updated

---

The test suite now provides a comprehensive TDD framework for ensuring complete Elm-Rust CLI compatibility. Use the checkbox format above to track your implementation progress!
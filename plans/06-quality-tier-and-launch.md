# Step 6: Quality Tier and Launch Preparation

**Phase:** 2 — Post-Engine  
**Iteration:** 6 — Quality Tier + Launch  
**Timeline:** Week 13+ (after core engine + editor)

## Objective

Add the optional 14B model quality tier, implement hardware detection and model recommendation, and prepare the project for distribution.

## Deliverables

- 14B model as optional quality tier
- Hardware detection and model recommendation at launch
- Model download/management system
- Configuration UI for LLM settings
- Packaging and distribution preparation

## Tasks

### 6.1 Optional 14B Model Tier

- [ ] Download Qwen 2.5 14B Instruct Q4_K_M GGUF model
- [ ] Configure model selection in engine:
  - [ ] `config.json` or settings file with model path
  - [ ] Support switching between 9B and 14B at launch
  - [ ] Validate model file exists before starting server
- [ ] Test 14B model with existing test story:
  - [ ] Compare dialogue quality vs. 9B
  - [ ] Compare generation speed vs. 9B
  - [ ] Verify JSON output compliance with 14B
  - [ ] Verify response validation works identically

### 6.2 Hardware Detection

- [ ] Implement hardware detection at launch:
  - [ ] Detect total system RAM
  - [ ] Detect GPU type and VRAM (if available)
  - [ ] Detect CPU cores
  - [ ] Detect Metal (macOS), Vulkan, or CPU-only
- [ ] Implement model recommendation logic:
  - [ ] **Minimum tier** (8 GB RAM, no GPU): 9B Q4_K_M, CPU inference
  - [ ] **Recommended tier** (16 GB RAM, 6 GB VRAM): 9B Q4_K_M, GPU inference
  - [ ] **Quality tier** (16 GB RAM, 8 GB+ VRAM): 14B Q4_K_M, GPU inference
- [ ] Display recommendation to user at first launch:
  - [ ] Show detected hardware
  - [ ] Recommend model tier
  - [ ] Allow manual override

### 6.3 Model Download and Management

- [ ] Implement model download system:
  - [ ] Check for model files on first launch
  - [ ] Download missing models (with progress indicator)
  - [ ] Verify model file integrity (SHA256 checksum)
  - [ ] Store models in application data directory
- [ ] Implement model management UI:
  - [ ] List available models
  - [ ] Show which models are downloaded
  - [ ] Download / remove models
  - [ ] Set active model
- [ ] Handle model update scenarios:
  - [ ] Check for newer model versions
  - [ ] Prompt user to update

### 6.4 Configuration UI

- [ ] Implement LLM settings panel:
  - [ ] Model selection (9B / 14B)
  - [ ] Server host and port
  - [ ] Context window size
  - [ ] Max tokens per response
  - [ ] Timeout settings
- [ ] Implement general settings panel:
  - [ ] Text speed (typewriter effect)
  - [ ] UI theme / colors
  - [ ] Font size
  - [ ] Save slot count
  - [ ] Auto-save toggle

### 6.5 Packaging and Distribution

- [ ] Prepare project structure for distribution:
  - [ ] `engine/` — Godot project and GDExtension
  - [ ] `models/` — GGUF model files (or download links)
  - [ ] `stories/` — story JSON files
  - [ ] `assets/` — images, sprites, audio
  - [ ] `scripts/` — server startup scripts
  - [ ] `prompts/` — prompt templates
- [ ] Create installer / packaging:
  - [ ] Linux: AppImage or .deb
  - [ ] macOS: .dmg
  - [ ] Windows: .exe installer
  - [ ] Include llama.cpp binary in package
- [ ] Create documentation:
  - [ ] README with setup instructions
  - [ ] Hardware requirements table
  - [ ] Model download guide
  - [ ] Troubleshooting guide
  - [ ] Story authoring guide (once editor is ready)

### 6.6 Verification

- [ ] Hardware detection correctly identifies system specs
- [ ] Model recommendation matches hardware tier
- [ ] 14B model loads and generates dialogue
- [ ] Model download completes with integrity verification
- [ ] Configuration UI persists settings
- [ ] Package installs and runs on target platforms

## Acceptance Criteria

- [ ] 14B model works as optional quality tier alongside 9B default
- [ ] Hardware detection accurately identifies system capabilities
- [ ] Model recommendation guides users to appropriate tier
- [ ] Model download and verification works end-to-end
- [ ] Configuration UI allows all relevant settings adjustments
- [ ] Project packages correctly for distribution on target platforms

## Dependencies

- Steps 1–5 (Engine Core + Story Editor) completed
- Qwen 2.5 14B Q4_K_M GGUF model available

## Notes

- Avoid Q3 and below quantization — quality degrades too much for dialogue
- Q5_K_M is an optional higher-quality variant for users with excess resources
- Base instruction-tuned models are preferred — reliable JSON output and constraint adherence
- Creativity is achieved through prompt engineering, not model size alone

# Step 2: LLM Integration

**Phase:** 1 — Engine Core  
**Iteration:** 2 — LLM Integration  
**Timeline:** Week 3–6

## Objective

Integrate **Embeddable Lemonade** (`lemond`) as a bundled subprocess LLM server. Build the Godot HTTP client, input parser, dialogue generator, and response validator so players can type natural language and receive NPC responses with structured metadata. All models and backends live in a **private directory** inside the project tree — no global HuggingFace cache, no system-wide installation.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Game Engine (Godot)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ State Machine │  │ Scene Manager│  │  Input Parser     │  │
│  │ (Step 1)      │  │ (Step 1)     │  │  (NL → intent)    │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬──────────┘  │
│         │                 │                    │             │
│  ┌──────▼─────────────────▼────────────────────▼───────────┐ │
│  │              LLM Integration Layer                       │ │
│  │  HttpClient  →  POST /v1/chat/completions (OpenAI API)  │ │
│  │  DialogueGenerator  →  persona + context → LLM call     │ │
│  │  ResponseValidator  →  engine-gated clue validation     │ │
│  └───────────────────────────┬─────────────────────────────┘ │
│                              │ HTTP/JSON                      │
└──────────────────────────────┼───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│              Embeddable Lemonade (lemond)                     │
│  • Private models in lemond/models/ (HF layout)              │
│  • Vulkan backend: lemond/bin/llamacpp/vulkan/llama-server   │
│  • Auth via LEMONADE_API_KEY + Bearer header                 │
│  • Config: lemond/config.json + recipe_options.json          │
└───────────────────────────────────────────────────────────────┘
```

## Deliverables

- Embeddable Lemonade (`lemond`) bundled with Vulkan backend and private model directory
- Qwen 3.5 9B Q4_K_M GGUF model in private `lemond/models/` directory
- HTTP client in engine (async, OpenAI-compatible `/v1/chat/completions`)
- Input parser (player NL → structured intent via LLM)
- Dialogue generator (NPC response + metadata)
- Response validator (check `revealed_clues` against engine-computed allowed set)
- Keyword fallback detection in dialogue text
- Server lifecycle manager (launch, health-check, shutdown)
- UI for player input, dialogue display, and loading states

## Tasks

### 2.1 Embeddable Lemonade Setup

**Goal:** Bundle `lemond` with Vulkan backend and a private model directory.

- [ ] Download embeddable Lemonade v10.3.0 artifact from [GitHub Releases](https://github.com/lemonade-sdk/lemonade/releases/tag/v10.3.0):
  - [ ] Linux: `lemonade-embeddable-10.3.0-ubuntu-x64.tar.gz` → extract to `lemond/`
  - [ ] Windows: `lemonade-embeddable-10.3.0-windows-x64.zip` → extract to `lemond/`
- [ ] Verify deployment-ready layout:

  ```
  lemond/
  ├── lemond [/.exe]                  # Server binary (subprocess)
  ├── lemonade [/.exe]                # CLI management tool
  ├── config.json                     # Persistent lemond settings
  ├── recipe_options.json             # Per-model load options
  ├── LICENSE
  ├── resources/
  │   ├── server_models.json          # Built-in model registry
  │   └── backend_versions.json       # Backend version pins
  ├── bin/
  │   └── llamacpp/
  │       └── vulkan/
  │           └── llama-server [/.exe]    # Vulkan GPU backend
  ├── models/                         # Private HF-layout model cache
  └── extra_models/                   # Custom GGUF files (not on HF)
  ```
  > `[.exe]` = Windows-only extension. All paths below use Unix-style notation;
  > on Windows, append `.exe` to executables and use `;` as path separator.

- [ ] Configure **private model directory**:
  - [ ] Set `models_dir` to `"./models"` in `config.json` (keeps models isolated from global `~/.cache/huggingface/hub` on Linux, `%LOCALAPPDATA%\Cache\huggingface\hub` on Windows)
  - [ ] Verify: `./lemond ./` (Linux) / `./lemond.exe ./` (Windows) + `./lemonade pull <model>` places models under `lemond/models/`
- [ ] Install Vulkan backend:
  - [ ] Start `lemond` briefly: `./lemond ./` (Linux) / `./lemond.exe ./` (Windows)
  - [ ] Run: `./lemonade backends install llamacpp:vulkan` (Linux) / `./lemonade.exe backends install llamacpp:vulkan` (Windows)
  - [ ] Verify `bin/llamacpp/vulkan/llama-server` (Linux) / `llama-server.exe` (Windows) exists
  - [ ] (Alternative) Set `llamacpp.vulkan_bin` in `config.json` to point to a custom `llama-server` binary
- [ ] Configure `config.json` for our use case:

  ```jsonc
  {
    "port": 13305,
    "host": "127.0.0.1",
    "models_dir": "./models",
    "extra_models_dir": "./extra_models",
    "ctx_size": 8192,
    "max_loaded_models": 1,
    "log_level": "info",
    "no_broadcast": true
  }
  ```

- [ ] Configure `recipe_options.json` for per-model settings:

  ```jsonc
  {
    "Qwen3.5-9B-Q4_K_M": {
      "ctx_size": 8192,
      "llamacpp_backend": "vulkan",
      "llamacpp_args": "--flash-attn 1"
    }
  }
  ```

- [ ] Download Qwen 3.5 9B Q4_K_M GGUF model:
  - [ ] Via Lemonade pull: `./lemonade pull Qwen3.5-9B-Q4_K_M` (Linux) / `./lemonade.exe pull Qwen3.5-9B-Q4_K_M` (Windows)
  - [ ] Or place custom GGUF in `lemond/extra_models/` and set `extra_models_dir` in config
  - [ ] Verify model appears: `./lemonade list` (Linux) / `./lemonade.exe list` (Windows)
- [ ] Create cross-platform startup scripts:
  - [ ] **Linux:** `scripts/start_llm.sh`
    - [ ] Sets `LEMONADE_API_KEY` (random or fixed key)
    - [ ] Launches `./lemond ./` as background subprocess from `lemond/` directory
    - [ ] Polls `GET /v1/health` until server is ready (with timeout)
    - [ ] Optionally pre-loads model via `POST /v1/load`
    - [ ] Handles graceful shutdown on exit (trap SIGTERM/SIGINT)
  - [ ] **Windows:** `scripts/start_llm.ps1`
    - [ ] Sets `$env:LEMONADE_API_KEY`
    - [ ] Launches `./lemond.exe ./` via `Start-Process` (passThru for PID tracking)
    - [ ] Polls `GET /v1/health` via `Invoke-RestMethod` until ready
    - [ ] Optionally pre-loads model via `POST /v1/load`
    - [ ] Handles graceful shutdown on script exit
  - [ ] **Linux:** `scripts/stop_llm.sh` — kills `lemond` process by PID or signal
  - [ ] **Windows:** `scripts/stop_llm.ps1` — stops `lemond.exe` process by ID
- [ ] Verify server responds:
  - [ ] **Linux:** `curl http://127.0.0.1:13305/v1/health -H "Authorization: Bearer $KEY"`
  - [ ] **Windows:** `Invoke-RestMethod -Uri http://127.0.0.1:13305/v1/health -Headers @{"Authorization"="Bearer $KEY"}`
  - [ ] Verify `GET /v1/models` lists the loaded model on both platforms

### 2.2 Server Lifecycle Manager (Godot side)

**Goal:** Godot launches, monitors, and communicates with `lemond` as a managed subprocess.

- [ ] Implement `ServerLifecycle` class in GDScript:
  - [ ] `start()` — launches `lemond` via `OS.execute()`:
    - [ ] Linux: `OS.execute("./lemond", ["./"], true)` with `LEMONADE_API_KEY` in env
    - [ ] Windows: `OS.execute("./lemond.exe", ["./"], true)` with env var set via `Environment` API
    - [ ] Resolves binary path: `res://lemond/lemond` (Linux) vs `res://lemond/lemond.exe` (Windows)
    - [ ] Uses `OS.get_name()` to detect platform and pick correct binary
    - [ ] Stores PID for later shutdown
  - [ ] `is_ready()` — polls `GET /v1/health` until 200 OK (configurable timeout, default 60s)
  - [ ] `stop()` — gracefully shuts down `lemond` process:
    - [ ] Linux: `OS.kill(pid, Signal.SIGTERM)` then `OS.kill(pid, Signal.SIGKILL)` after timeout
    - [ ] Windows: `OS.execute("taskkill", ["/F", "/PID", str(pid)], true)` or `ProcessTree` API
  - [ ] `get_api_key()` — returns the auth key for HTTP requests
  - [ ] `get_base_url()` — returns `http://127.0.0.1:<port>`
  - [ ] Signal: `server_ready()` — emitted when health check passes
  - [ ] Signal: `server_error(error_msg)` — emitted on startup failure
  - [ ] Detects `lemond` data directory relative to executable (`ProjectSettings.globalize_path("res://lemond/")`)
- [ ] Implement system info detection (optional, for future backend switching):
  - [ ] `GET /v1/system-info` — check available backends (ROCm vs Vulkan)
  - [ ] Log detected GPU capabilities at startup

### 2.3 HTTP Client

**Goal:** Async HTTP client for OpenAI-compatible chat completions with auth and error handling.

- [ ] Implement `LlmHttpClient` class in GDScript:
  - [ ] `chat_completion(messages, model, options)` → `HTTPClient.RequestResult`
    - [ ] `POST /v1/chat/completions` with JSON body
    - [ ] Attaches `Authorization: Bearer <key>` header
    - [ ] Configurable base URL (default: `http://127.0.0.1:13305`)
    - [ ] Timeout handling (60s default for generation, 10s for health checks)
    - [ ] Async via Godot `HTTPClient` (non-blocking for UI responsiveness)
  - [ ] `health_check()` → `bool` — `GET /v1/health`
  - [ ] `load_model(model_name)` → `bool` — `POST /v1/load`
  - [ ] `unload_model(model_name)` → `bool` — `POST /v1/unload`
  - [ ] Error handling:
    - [ ] Connection refused → server not running
    - [ ] Timeout → generation took too long
    - [ ] 401 → auth key mismatch
    - [ ] Malformed JSON → log raw response for debugging
  - [ ] Retry logic: configurable max retries with exponential backoff
- [ ] Define `LlmRawResponse` struct (direct mapping from API response):
  - [ ] `choices[0].message.content` (string) — raw LLM output
  - [ ] `usage.prompt_tokens` (int)
  - [ ] `usage.completion_tokens` (int)
  - [ ] `model` (string) — which model generated the response
- [ ] Define `LlmResponse` struct (engine's parsed response):
  - [ ] `dialogue` (string) — NPC spoken text
  - [ ] `revealed_clues` (array of strings) — clue IDs revealed in this response
  - [ ] `emotional_state` (string) — NPC current emotional state
  - [ ] `raw_content` (string) — unparsed LLM output for debugging
- [ ] Implement `LlmResponseParser`:
  - [ ] `parse(raw_response)` → `LlmResponse`
  - [ ] Extracts JSON block from LLM output (handles markdown code fences)
  - [ ] Validates required fields (`dialogue` must be present)
  - [ ] Defaults missing optional fields to safe values

### 2.4 System Prompts / Persona Cards

**Goal:** Rich, structured prompts that produce consistent, constraint-respecting LLM output.

- [ ] Design system prompt template for NPC dialogue generation:
  - [ ] **Character persona section** — name, personality, speech patterns, secrets, knowledge limits
  - [ ] **Scene context section** — location, situation, other characters present, time of day
  - [ ] **Available clues section** — what the NPC can reveal right now (engine-computed list)
  - [ ] **Conversation history** — last 3–5 exchanges for continuity
  - [ ] **Constraint section** — explicit JSON output format, what NOT to reveal, tone guidelines
  - [ ] **Few-shot examples** — 2–3 example interactions showing expected output format
- [ ] Design system prompt template for input parsing:
  - [ ] **Player intent extraction** — greet, ask_about, accuse, offer_item, leave, search, examine
  - [ ] **Entity extraction** — which NPC, which topic, which item
  - [ ] **JSON output format** — strict schema for parsed intent
  - [ ] **Fallback instructions** — what to do when intent is ambiguous
- [ ] Store templates in `prompts/` directory:
  - [ ] `prompts/dialogue_system.txt` — NPC dialogue generation template
  - [ ] `prompts/input_parser_system.txt` — intent parsing template
  - [ ] Templates use `{placeholder}` syntax for runtime substitution
- [ ] Implement `PromptBuilder` class:
  - [ ] `build_dialogue_prompt(npc_persona, scene_context, available_clues, conversation_history, player_input)` → `Array[Dictionary]` (OpenAI messages format)
  - [ ] `build_parser_prompt(player_input, present_npcs, scene_items)` → `Array[Dictionary]`
  - [ ] Loads template files from `prompts/`
  - [ ] Substitutes placeholders with runtime values
  - [ ] Respects context window limits (truncates history if needed)

### 2.5 Input Parser

**Goal:** Convert player natural language into structured intents the engine can act on.

- [ ] Implement `InputParser` class:
  - [ ] `parse(player_input, current_scene, present_npcs)` → `ParsedIntent`
  - [ ] Constructs prompt from template + context + player input
  - [ ] Calls LLM via `LlmHttpClient`
  - [ ] Parses JSON response into structured intent
  - [ ] Fallback: if LLM returns invalid JSON, attempt keyword-based intent detection
  - [ ] Signal: `parse_complete(intent)` — emitted when parsing finishes
  - [ ] Signal: `parse_error(error_msg)` — emitted on failure
- [ ] Define `ParsedIntent` struct:
  - [ ] `action` (string) — greet, ask_about, accuse, offer_item, leave, search, examine, etc.
  - [ ] `target_npc` (string or null) — which NPC the action targets
  - [ ] `topic` (string or null) — what the player is asking about
  - [ ] `item` (string or null) — which item is being offered/referenced
  - [ ] `raw_input` (string) — original player input for context
  - [ ] `confidence` (float, 0.0–1.0) — parser confidence (from LLM or heuristic)
- [ ] Implement keyword-based fallback:
  - [ ] Action keywords: "hello/greet", "ask/tell about", "accuse", "give/show", "leave/go", "search/look"
  - [ ] NPC name matching: case-insensitive substring match against present NPCs
  - [ ] Topic extraction: noun phrases after "about", "regarding", "concerning"

### 2.6 Dialogue Generator

**Goal:** Generate character-appropriate NPC dialogue with structured metadata.

- [ ] Implement `DialogueGenerator` class:
  - [ ] `generate(parsed_intent, npc_id, scene_id, available_clues)` → `LlmResponse`
  - [ ] Constructs prompt from persona card + scene context + intent + available clues
  - [ ] Calls LLM via `LlmHttpClient`
  - [ ] Parses response via `LlmResponseParser`
  - [ ] Signal: `dialogue_generated(response)` — emitted on success
  - [ ] Signal: `generation_error(error_msg)` — emitted on failure
- [ ] Implement context assembly:
  - [ ] Load NPC persona from story data (characters section)
  - [ ] Load scene description and current situation from `SceneManager`
  - [ ] Compute available clues from engine state (not from LLM)
  - [ ] Include recent conversation history (last 3–5 exchanges, stored in session)
  - [ ] Respect context window: truncate oldest messages if approaching `ctx_size` limit
- [ ] Implement conversation history manager:
  - [ ] `add_exchange(player_input, npc_response)` — stores a dialogue turn
  - [ ] `get_recent(n)` → `Array[String]` — last n exchanges
  - [ ] `clear()` — resets history (e.g., on scene change)
  - [ ] Token-aware: tracks approximate token count to stay within context window

### 2.7 Response Validator

**Goal:** Never trust LLM output for game logic. Validate all claimed clues against engine state.

- [ ] Implement `ResponseValidator` class:
  - [ ] `validate(response, available_clues)` → `ValidatedResponse`
  - [ ] Check each claimed `revealed_clue` against the engine-computed available set
  - [ ] Reject clues not in the available set (never trust blindly)
  - [ ] Keyword fallback: scan dialogue text for clue keywords if metadata is missing
  - [ ] Log validation discrepancies for debugging
- [ ] Define `ValidatedResponse` struct:
  - [ ] `dialogue` (string) — final NPC dialogue text (unchanged)
  - [ ] `accepted_clues` (array of strings) — clues validated as legitimate
  - [ ] `rejected_clues` (array of strings) — clues the LLM claimed but engine rejected
  - [ ] `keyword_detected_clues` (array of strings) — clues found via keyword scan
  - [ ] `emotional_state` (string) — from LLM metadata
- [ ] Implement keyword detection system:
  - [ ] Define keyword mappings per clue in story JSON (`clue.keywords` array)
  - [ ] Scan dialogue text for keyword matches (case-insensitive)
  - [ ] Auto-detect revealed clues from text if LLM omits metadata
  - [ ] Merge keyword-detected clues with metadata-reported clues (deduplicated)
- [ ] Update story JSON schema to support clue keywords:
  ```jsonc
  "clues": {
    "the_hidden_key": {
      "description": "A brass key hidden behind a book",
      "keywords": ["brass key", "hidden key", "key behind the book"],
      "source": "library",
      "prerequisites": { "searched_library": true }
    }
  }
  ```

### 2.8 UI Updates

**Goal:** Player-facing dialogue interface with input, loading states, and error handling.

- [ ] Add player input text field:
  - [ ] `LineEdit` at bottom of screen
  - [ ] Submit on Enter key
  - [ ] Disabled during LLM generation
  - [ ] Placeholder text: "What do you want to say or do?"
- [ ] Enhance dialogue display:
  - [ ] Typewriter-style text animation for NPC responses
  - [ ] Skip animation on click/keypress
  - [ ] NPC name header above each response
  - [ ] Distinct styling for player input vs NPC dialogue vs narration
- [ ] Add NPC portrait/name display area:
  - [ ] Character name label (top-left or inline)
  - [ ] Placeholder for portrait image (future: `characters/<name>.png`)
- [ ] Add loading indicator during LLM generation:
  - [ ] Animated dots or spinner overlay
  - [ ] "Thinking…" label
  - [ ] Blocks input during generation
- [ ] Add error display for connection failures:
  - [ ] Non-intrusive toast/notification banner
  - [ ] "Server unavailable — check connection" message
  - [ ] Retry button
- [ ] Wire full pipeline: input → parser → dialogue generator → validator → display

### 2.9 Configuration and Settings

**Goal:** Externalize all LLM-related configuration for easy tuning. Platform-specific paths are resolved at runtime.

- [ ] Create `config/llm.json`:
  ```jsonc
  {
    "lemonade_version": "10.3.0",
    "server": {
      "data_dir": ".lemond/",
      "binary_linux": "lemond",
      "binary_windows": "lemond.exe",
      "host": "127.0.0.1",
      "port": 13305,
      "api_key": "novelgen-dev-key",
      "health_check_interval_ms": 2000,
      "startup_timeout_s": 60
    },
    "model": {
      "name": "Qwen3.5-9B-Q4_K_M",
      "ctx_size": 8192,
      "max_tokens": 1024
    },
    "client": {
      "request_timeout_s": 60,
      "max_retries": 2,
      "retry_backoff_ms": 1000
    }
  }
  ```
- [ ] Implement `LlmConfig` autoload singleton:
  - [ ] Loads `config/llm.json` on startup
  - [ ] Provides typed accessors for all settings
  - [ ] Platform-aware path resolution:
    - [ ] `get_binary()` → returns `lemond` or `lemond.exe` based on `OS.get_name()`
    - [ ] `get_cli()` → returns `lemonade` or `lemonade.exe` based on `OS.get_name()`
    - [ ] `get_data_dir()` → globalized absolute path to `res://lemond/`
  - [ ] Validates required fields
  - [ ] Logs configuration at startup for debugging (includes detected platform)

### 2.10 Verification

- [ ] Start `lemond` via startup script (`.sh` on Linux, `.ps1` on Windows), verify engine connects via health check
- [ ] Verify `GET /v1/health` returns 200 with model info
- [ ] Verify `GET /v1/models` lists the loaded model
- [ ] Type natural language input, receive NPC response within reasonable time
- [ ] Verify `ParsedIntent` correctly extracts action and target
- [ ] Verify `LlmResponse` includes dialogue and metadata
- [ ] Verify response validator rejects invalid clue claims
- [ ] Verify error handling when server is down (graceful message, no crash)
- [ ] Verify model lives in private `lemond/models/` (not in `~/.cache/huggingface/` on Linux, not in `%LOCALAPPDATA%\Cache\huggingface\` on Windows)
- [ ] Verify Vulkan backend is used (check `lemond` logs or `/v1/stats`)
- [ ] Verify conversation history persists across exchanges within a scene
- [ ] Verify history clears on scene transition
- [ ] **Cross-platform:** Verify full flow (start → chat → stop) works on both Linux and Windows
- [ ] **Cross-platform:** Verify `LlmConfig.get_binary()` returns correct path per platform
- [ ] **Cross-platform:** Verify `ServerLifecycle.stop()` cleanly kills the process per platform

## Acceptance Criteria

- [ ] Embeddable `lemond` launches as a subprocess with Vulkan backend
- [ ] Model stored in private `lemond/models/` directory (no global cache dependency)
- [ ] Engine HTTP client successfully communicates with `lemond` via OpenAI-compatible API
- [ ] Auth headers (`Authorization: Bearer`) work correctly
- [ ] Server lifecycle manager handles start, health-check, and shutdown
- [ ] Player natural language input is parsed into structured intent
- [ ] NPC dialogue is generated with character-appropriate voice
- [ ] Response metadata (`revealed_clues`, `emotional_state`) is returned and parsed
- [ ] Response validator correctly accepts valid clues and rejects invalid ones
- [ ] Keyword fallback detects clues when LLM omits metadata
- [ ] UI displays dialogue with typewriter animation, accepts input, shows loading state
- [ ] Error handling works gracefully when server is unavailable
- [ ] All LLM configuration is externalized in `config/llm.json`

## Dependencies

- Step 1 (Engine Core Setup) completed
- Embeddable Lemonade v10.3.0 downloaded from [GitHub Releases](https://github.com/lemonade-sdk/lemonade/releases/tag/v10.3.0) and extracted to `lemond/`
- Vulkan backend installed in `lemond/bin/llamacpp/vulkan/`
- Qwen 3.5 9B Q4_K_M GGUF model in `lemond/models/` or `lemond/extra_models/`
- Vulkan drivers installed on target system (Linux: `vulkan-tools` / `mesa-vulkan-drivers`; Windows: GPU vendor driver)

## Directory Layout (after this step)

```
ai-novelgen/
├── project.godot
├── config/
│   └── llm.json                      # LLM server + client configuration
├── docs/
│   └── story_json_format.md
├── lemond/                           # Embeddable Lemonade v10.3.0 (private)
│   ├── lemond [.exe]                 # Server binary
│   ├── lemonade [.exe]               # CLI tool
│   ├── config.json                   # Lemond runtime settings
│   ├── recipe_options.json           # Per-model load options
│   ├── resources/
│   │   ├── server_models.json
│   │   └── backend_versions.json
│   ├── bin/
│   │   └── llamacpp/
│   │       └── vulkan/
│   │           └── llama-server [.exe]  # Vulkan backend
│   ├── models/                       # Private model cache (HF layout)
│   └── extra_models/                 # Custom GGUF files
├── prompts/
│   ├── dialogue_system.txt           # NPC dialogue prompt template
│   └── input_parser_system.txt       # Intent parsing prompt template
├── scripts/
│   ├── start_llm.sh                  # Launch lemond + health check (Linux)
│   ├── start_llm.ps1                 # Launch lemond + health check (Windows)
│   ├── stop_llm.sh                   # Graceful shutdown (Linux)
│   └── stop_llm.ps1                  # Graceful shutdown (Windows)
├── scenes/
│   └── main.tscn
├── src/
│   ├── game_state.gd                 # GameState autoload (Step 1)
│   ├── scene_manager.gd              # SceneManager (Step 1)
│   ├── main_controller.gd            # Main UI controller (Step 1)
│   ├── llm_config.gd                 # LLM config autoload (NEW)
│   ├── server_lifecycle.gd           # lemond subprocess manager (NEW)
│   ├── llm_http_client.gd            # Async HTTP client (NEW)
│   ├── llm_response_parser.gd        # Raw → LlmResponse parsing (NEW)
│   ├── prompt_builder.gd             # Template → messages assembly (NEW)
│   ├── input_parser.gd               # NL → ParsedIntent (NEW)
│   ├── dialogue_generator.gd         # Intent → NPC dialogue (NEW)
│   ├── conversation_history.gd       # Session dialogue tracker (NEW)
│   └── response_validator.gd         # Clue validation + keyword scan (NEW)
└── stories/
    └── test_story.json
```

## Key Lemonade Concepts Used

| Concept | How We Use It | Reference |
|---|---|---|
| **Embeddable artifact** | Bundled `lemond/` directory, launched as subprocess | [Embeddable Overview](https://lemonade-server.ai/docs/embeddable/) |
| **Private models** | `models_dir: "./models"` — no global HF cache | [Private Models](https://lemonade-server.ai/docs/embeddable/models/) |
| **Extra models dir** | `extra_models_dir: "./extra_models"` for non-HF GGUF files | [Importing Models](https://lemonade-server.ai/docs/embeddable/models/) |
| **Vulkan backend** | `bin/llamacpp/vulkan/llama-server` via `lemonade backends install llamacpp:vulkan` | [Backends](https://lemonade-server.ai/docs/embeddable/backends/) |
| **API key auth** | `LEMONADE_API_KEY` env var + `Authorization: Bearer` header | [Runtime: Authenticating](https://lemonade-server.ai/docs/embeddable/runtime/) |
| **Health endpoint** | `GET /v1/health` for startup readiness polling | [Lemonade API: /v1/health](https://lemonade-server.ai/docs/api/lemonade/) |
| **Model load/unload** | `POST /v1/load` and `/v1/unload` for lifecycle control | [Lemonade API: /v1/load](https://lemonade-server.ai/docs/api/lemonade/) |
| **System info** | `GET /v1/system-info` for GPU/backend detection | [Lemonade API: /v1/system-info](https://lemonade-server.ai/docs/api/lemonade/) |
| **Internal config** | `POST /internal/set` for runtime setting changes | [Runtime Settings](https://lemonade-server.ai/docs/embeddable/runtime/) |
| **OpenAI API** | `POST /v1/chat/completions` for all LLM calls | [OpenAI-Compatible API](https://lemonade-server.ai/docs/api/openai/) |
| **Per-model options** | `recipe_options.json` for ctx_size, backend, args | [Per-Model Load Options](https://lemonade-server.ai/docs/embeddable/models/) |
| **Multi-model LRU** | `max_loaded_models: 1` (single model for now) | [Multi-Model Support](https://lemonade-server.ai/docs/api/multi-model/) |
| **Cross-platform** | `OS.get_name()` → Linux/Windows binary selection | Godot `OS` API |

## Notes

- **LLM is a delivery mechanism, not the source of truth.** The engine owns all game state.
- **Never trust LLM output for game logic.** Always validate `revealed_clues` against the engine-computed available set.
- **Prompt quality is critical** — invest in rich persona cards, explicit constraints, and structured tool calling.
- **Private directory is mandatory** — models must never leak into the global HuggingFace cache. This ensures reproducible builds and clean uninstallation.
- **Vulkan backend** is the default GPU acceleration path. ROCm can be added later via `POST /v1/install` if AMD GPU is detected.
- Consider adding a **local HTTP mock server** for testing the engine without `lemond` running.
- The `LEMONADE_API_KEY` is a local security measure to prevent other apps on the system from accessing our `lemond` instance. It does not need to be cryptographically strong for development.

## Cross-Platform Notes

- **Lemonade version:** 10.3.0 — pinned to a specific [GitHub release](https://github.com/lemonade-sdk/lemonade/releases/tag/v10.3.0) for reproducibility.
- **Binary naming:** `lemond` / `lemond.exe`, `lemonade` / `lemonade.exe`, `llama-server` / `llama-server.exe`. All code must resolve the correct extension via `OS.get_name()`.
- **Path separators:** `config.json` uses forward-slash relative paths (`./models`, `./extra_models`) which work on both Linux and Windows.
- **Environment variables:** Linux uses `KEY=value && command` syntax; Windows uses `$env:KEY="value"` in PowerShell. The Godot `ServerLifecycle` uses `OS.execute()` which handles env vars differently per platform.
- **Process management:** Linux uses `OS.kill(pid, signal)`; Windows requires `taskkill` or the Godot `MultiplayerAPI` process tree. The `ServerLifecycle.stop()` method abstracts this.
- **Vulkan drivers:** Linux requires `vulkan-tools` and appropriate Mesa/NVIDIA drivers. Windows gets Vulkan support from standard GPU vendor drivers (NVIDIA GeForce, AMD Adrenalin, Intel Graphics).
- **Godot export:** When exporting the game, the `lemond/` directory must be included as data (not compiled into the pck). Use `--export-preset` with `filters/*` to exclude `lemond/` from the PCK and ship it as a separate directory alongside the executable.

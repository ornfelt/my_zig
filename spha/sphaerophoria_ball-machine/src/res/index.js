import {
  canvas_width,
  renderChamberIntoCanvas,
  renderBallsIntoCanvas,
  clearBounds,
} from "./chamber_renderer.js";
import { makeChamber } from "./wasm.js";
import { sanitize } from "./sanitize.js";

function loadChamber(chamber, chamber_state) {
  const len = chamber_state.length;
  const chamber_save = chamber.instance.exports.saveMemory();
  const arr = new Uint8Array(
    chamber.instance.exports.memory.buffer,
    chamber_save,
    len,
  );
  arr.set(chamber_state);
  chamber.instance.exports.load();
}

class RemoteChamber {
  constructor(id, chamber, canvas_height) {
    this.chamber = chamber;
    this.id = id;
    const chamber_pixel_len = Math.ceil(
      canvas_width * canvas_width * canvas_height,
    );
    chamber.instance.exports.init(0, chamber_pixel_len);
  }

  async render(simulation_state, canvas, bounds, offscreen_canvas) {
    loadChamber(this.chamber, simulation_state.chamber_states[this.id]);

    const ctx = canvas.getContext("2d");
    ctx.filter = document.getElementById("filter").value;
    await renderChamberIntoCanvas(
      this.chamber,
      canvas,
      bounds,
      offscreen_canvas,
    );
    ctx.filter = "none";
    const balls = simulation_state.chamber_balls[this.id];
    renderBallsIntoCanvas(balls, canvas, bounds);
  }
}

class EmptyChamber {
  constructor(id) {
    this.id = id;
  }

  async render(simulation_state, canvas, bounds) {
    clearBounds(canvas, bounds);
    const balls = simulation_state.chamber_balls[this.id];
    renderBallsIntoCanvas(balls, canvas, bounds);
  }
}

let relayout_queue = Promise.resolve();

class ChamberRegistry {
  constructor(
    parent,
    large_canvas,
    chamber_ids,
    chambers_per_row,
    chamber_height,
  ) {
    this.parent = parent;
    this.large_canvas = large_canvas;
    this.chambers = [];
    this.chamber_height = chamber_height;
    this.simulation_queue = [];
    this.last_step = 0;
    this.relayout(chamber_ids, chambers_per_row);
    this.chambers_per_row = chambers_per_row;
    this.updateQueue();
    this.render();
    this.scheduler_offs = 300 * 16;
    this.x_offs = 0;
    this.y_offs = 0;
  }

  async relayout(chamber_ids, chambers_per_row) {
    this.chambers_per_row = chambers_per_row;
    this.parent.innerHTML = "";
    this.chambers = [];

    this.large_canvas.width = chambers_per_row * canvas_width;
    const num_rows = Math.ceil(chamber_ids.length / chambers_per_row);
    this.large_canvas.height = num_rows * canvas_width * this.chamber_height;

    let i = 0;
    for (; i < chamber_ids.length; ++i) {
      const obj = await makeChamber("/" + chamber_ids[i] + "/chamber.wasm");
      this.chambers.push(
        new RemoteChamber(i, obj, Math.ceil(this.chamber_height)),
      );
    }

    const end_empty_chambers =
      chamber_ids.length +
      ((chambers_per_row - (chamber_ids.length % chambers_per_row)) %
        chambers_per_row);
    for (; i < end_empty_chambers; ++i) {
      this.chambers.push(new EmptyChamber(i));
    }
  }

  async updateQueue() {
    const simulation_response = await fetch(
      "/simulation_state?since=" + this.last_step,
    );
    const new_elems = await simulation_response.json();
    const retrieved_time = performance.now();
    for (let i = 0; i < new_elems.length; i += 1) {
      const elem = new_elems[new_elems.length - i - 1];
      elem.estimated_time = retrieved_time - 16 * i;
    }
    // Weighted avergae offset
    const new_offs = 16 * new_elems.length;
    if (new_offs > this.scheduler_offs) {
      this.scheduler_offs = new_offs;
    } else {
      this.scheduler_offs = this.scheduler_offs * 0.8 + new_offs * 0.2;
    }
    this.simulation_queue = [...this.simulation_queue, ...new_elems];
    this.last_step = new_elems[new_elems.length - 1].num_steps_taken;
    window.setTimeout(() => this.updateQueue(), 300);
  }

  getNextFrame() {
    const now = performance.now();
    if (this.simulation_queue.length < 1) {
      return null;
    }

    let i = 0;
    while (i < this.simulation_queue.length) {
      if (this.simulation_queue[i].estimated_time + this.scheduler_offs > now) {
        break;
      }
      i += 1;
    }

    if (i == 0) {
      return null;
    }

    const ret = this.simulation_queue[i - 1];
    this.simulation_queue.splice(0, i - 1);
    return ret;
  }

  async render() {
    window.requestAnimationFrame(() => this.render());
    const simulation_state = this.getNextFrame();
    if (simulation_state === null) {
      return;
    }

    this.x_offs += 0.05;
    this.y_offs += 0.01;
    this.x_offs %= this.large_canvas.width;
    this.y_offs += this.large_canvas.height;

    const canvas_height = Math.floor(this.chamber_height * canvas_width);
    const offscreen_canvas = new OffscreenCanvas(canvas_width, canvas_height);

    for (let i = 0; i < this.chambers.length; i++) {
      const chamber = this.chambers[i];

      const row = Math.floor(i / this.chambers_per_row);
      const col = i % this.chambers_per_row;
      const bounds = {
        x: col * canvas_width + this.x_offs,
        y: Math.floor(row * this.chamber_height * canvas_width) + this.y_offs,
        width: canvas_width,
        height: canvas_height,
      };
      try {
        chamber.render(
          simulation_state,
          this.large_canvas,
          bounds,
          offscreen_canvas,
        );
      } catch (e) {}
    }
  }
}

async function init() {
  // FIXME: Do all requests at same time
  const init_info_response = await fetch("/init_info");
  const init_info = await init_info_response.json();

  const chamber_height = init_info.chamber_height;
  const chambers_per_row = init_info.chambers_per_row;
  const num_balls = init_info.num_balls;
  const chamber_ids = init_info.chamber_ids;

  const large_canvas = document.getElementById("large_canvas");
  const chambers_div = document.getElementById("chambers");
  const registry = new ChamberRegistry(
    chambers_div,
    large_canvas,
    chamber_ids,
    chambers_per_row,
    chamber_height,
  );

  const num_balls_spinner = document.getElementById("num_balls");
  num_balls_spinner.value = num_balls;
  num_balls_spinner.onchange = (ev) => {
    const req = new Request("/num_balls", {
      method: "PUT",
      body: ev.target.value.toString(),
    });
    fetch(req);
  };

  const style = document.querySelector("#chambers");
  style.style.setProperty("--num-columns", chambers_per_row);

  const chambers_per_row_spinner = document.getElementById("chambers_per_row");
  chambers_per_row_spinner.value = chambers_per_row;
  chambers_per_row_spinner.onchange = (ev) => {
    relayout_queue = relayout_queue.then(async () => {
      try {
        const req = new Request("/chambers_per_row", {
          method: "PUT",
          body: ev.target.value.toString(),
        });
        await fetch(req);
        await registry.relayout(chamber_ids, ev.target.value);
        style.style.setProperty("--num-columns", ev.target.value);
      } catch (e) {}
    });
  };

  const reset_button = document.getElementById("reset");
  reset_button.onclick = () => fetch("/reset");

  const userinfo_response = await fetch("/userinfo");
  const userinfo = await userinfo_response.json();
  document.getElementById("username").innerHTML =
    "hello " + sanitize(userinfo.name);

  if (userinfo.is_admin === true) {
    const admin_options = document.getElementById("admin_options");
    admin_options.style.display = "unset";
  }
}

window.onload = init;

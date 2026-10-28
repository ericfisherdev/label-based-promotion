export class TodoList {
  #items = [];
  #nextId = 1;

  add(title) {
    const trimmed = String(title ?? '').trim();
    if (trimmed === '') {
      throw new Error('Title must not be empty.');
    }

    const item = { id: this.#nextId++, title: trimmed, done: false };
    this.#items.push(item);

    return { ...item };
  }

  complete(id) {
    const item = this.#find(id);
    item.done = true;

    return { ...item };
  }

  search(text) {
    const needle = String(text ?? '').trim().toLowerCase();

    return this.list().filter((item) => item.title.toLowerCase().includes(needle));
  }

  rename(id, title) {
    const trimmed = String(title ?? '').trim();
    if (trimmed === '') {
      throw new Error('Title must not be empty.');
    }

    const item = this.#find(id);
    item.title = trimmed;

    return { ...item };
  }

  remove(id) {
    const item = this.#find(id);
    this.#items = this.#items.filter((candidate) => candidate !== item);
  }

  clearCompleted() {
    const before = this.#items.length;
    this.#items = this.#items.filter((item) => !item.done);

    return before - this.#items.length;
  }

  list() {
    return this.#items.map((item) => ({ ...item }));
  }

  toJSON() {
    return { nextId: this.#nextId, items: this.list() };
  }

  static fromJSON(data) {
    const list = new TodoList();
    list.#items = (data?.items ?? []).map((item) => ({ ...item }));
    list.#nextId = data?.nextId ?? list.#items.length + 1;

    return list;
  }

  #find(id) {
    const item = this.#items.find((candidate) => candidate.id === id);
    if (item === undefined) {
      throw new Error(`No to-do with id ${id}.`);
    }

    return item;
  }
}

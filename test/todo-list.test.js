import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TodoList } from '../src/todo-list.js';

test('add gives each item a new id', () => {
  const list = new TodoList();

  assert.deepEqual(list.add('Buy milk'), { id: 1, title: 'Buy milk', done: false });
  assert.equal(list.add('Walk dog').id, 2);
});

test('add rejects an empty title', () => {
  assert.throws(() => new TodoList().add('   '), /must not be empty/);
});

test('complete marks the item done', () => {
  const list = new TodoList();
  const { id } = list.add('Buy milk');

  assert.equal(list.complete(id).done, true);
  assert.equal(list.list()[0].done, true);
});

test('remove deletes the item', () => {
  const list = new TodoList();
  const { id } = list.add('Buy milk');
  list.remove(id);

  assert.deepEqual(list.list(), []);
});

test('clearCompleted removes done items and returns the count', () => {
  const list = new TodoList();
  list.add('Buy milk');
  const { id } = list.add('Walk dog');
  list.complete(id);

  assert.equal(list.clearCompleted(), 1);
  assert.deepEqual(list.list().map((item) => item.title), ['Buy milk']);
});

test('complete and remove reject an unknown id', () => {
  const list = new TodoList();

  assert.throws(() => list.complete(99), /No to-do with id 99/);
  assert.throws(() => list.remove(99), /No to-do with id 99/);
});

test('fromJSON restores items and keeps ids unique', () => {
  const list = new TodoList();
  list.add('Buy milk');
  list.add('Walk dog');
  list.remove(1);

  const restored = TodoList.fromJSON(JSON.parse(JSON.stringify(list)));

  assert.deepEqual(restored.list(), [{ id: 2, title: 'Walk dog', done: false }]);
  assert.equal(restored.add('Read book').id, 3);
});

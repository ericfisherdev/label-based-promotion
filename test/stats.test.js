import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TodoList } from '../src/todo-list.js';

test('stats counts total, done and open items', () => {
  const list = new TodoList();
  list.add('Buy milk');
  const { id } = list.add('Walk dog');
  list.complete(id);

  assert.deepEqual(list.stats(), { total: 2, done: 1, open: 1 });
});

test('stats of an empty list is all zero', () => {
  assert.deepEqual(new TodoList().stats(), { total: 0, done: 0, open: 0 });
});

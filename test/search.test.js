import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TodoList } from '../src/todo-list.js';

test('search finds items by title, ignoring case', () => {
  const list = new TodoList();
  list.add('Buy milk');
  list.add('Walk dog');
  list.add('Buy MILK powder');

  assert.deepEqual(list.search('milk').map((item) => item.id), [1, 3]);
});

test('search returns copies, not the stored items', () => {
  const list = new TodoList();
  list.add('Buy milk');
  list.search('milk')[0].title = 'changed';

  assert.equal(list.list()[0].title, 'Buy milk');
});

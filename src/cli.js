#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { TodoList } from './todo-list.js';

const STORE = process.env.TODO_FILE ?? 'todos.json';

function load() {
  return existsSync(STORE) ? TodoList.fromJSON(JSON.parse(readFileSync(STORE, 'utf8'))) : new TodoList();
}

function save(list) {
  writeFileSync(STORE, JSON.stringify(list, null, 2));
}

function print(list) {
  for (const item of list.list()) {
    console.log(`${item.done ? '[x]' : '[ ]'} ${item.id}. ${item.title}`);
  }
}

const [command, ...args] = process.argv.slice(2);
const list = load();

try {
  switch (command) {
    case 'add':
      list.add(args.join(' '));
      break;
    case 'done':
      list.complete(Number(args[0]));
      break;
    case 'mv':
      list.rename(Number(args[0]), args.slice(1).join(' '));
      break;
    case 'rm':
      list.remove(Number(args[0]));
      break;
    case 'ls':
    case undefined:
      break;
    default:
      console.error('Usage: todo [add <title> | done <id> | mv <id> <title> | rm <id> | ls]');
      process.exit(2);
  }
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

save(list);
print(list);

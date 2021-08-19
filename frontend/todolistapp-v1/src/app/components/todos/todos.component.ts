import { Component, OnInit } from '@angular/core';
import {Todo} from './../../models/Todo'
import { UUID } from 'angular2-uuid';

@Component({
  selector: 'app-todos',
  templateUrl: './todos.component.html',
  styleUrls: ['./todos.component.css']
})
export class TodosComponent implements OnInit { 

  todos: Todo[] = [];

  inputTodo:string = "";

  constructor() { }

  ngOnInit(): void {
    // need to create a function to retrive from db
    this.todos = [
      {
        id: "75d0fa1a-ae25-4823-9798-be98635b1b90",
        content: 'First todo',
        completed: false
      },
      {
        id: "399e7402-1f6d-4872-b7a4-ab05aeb8bd78",
        content: 'Second todo',
        completed: false
      }
    ]
  }

  toggleDone(id:number) {
    // need to call the db and modify the todo
    this.todos.map((v,i) => {
      if(i == id) v.completed = !v.completed

      return v;
    })
  }

  deleteTodo(id:number) {
    // need to call the db and mdelete the todo
    this.todos = this.todos.filter((v,i) => i !== id);
  }

  addTodo(): void {
    // need to call the db and add a new todo
    if(this.inputTodo != ""){
      let myId = UUID.UUID();
      this.todos.push({
        id: myId,
        content:this.inputTodo,
        completed: false
      });

      console.log(this.todos)
  
      this.inputTodo = "";
    }
  }

}

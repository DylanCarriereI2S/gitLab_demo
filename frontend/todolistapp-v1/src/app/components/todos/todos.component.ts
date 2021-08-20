import { Component, OnInit } from '@angular/core';
import {Todo} from './../../models/Todo'
import { UUID } from 'angular2-uuid';
import { environment } from 'src/environments/environements.terraform';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-todos',
  templateUrl: './todos.component.html',
  styleUrls: ['./todos.component.css']
})
export class TodosComponent implements OnInit { 

  todos: Todo[] = [];

  inputTodo:string = "";

  constructor(private http: HttpClient) { }

  ngOnInit(): void {
    // need to create a function to retrive from db
    this.getTodos();

  }

  getTodos() {
    this.http.get<any>(`${environment.apiUrl}/get-todos`).subscribe(data => {
      console.log(data.todoList);
      data.todoList.forEach((element: Todo) => {
        this.todos.push(element);
      });
    })
  }

  toggleDone(id:number) {
    // need to call the db and modify the todo
    let todoPost = this.todos[id];
    this.http.post<any>(`${environment.apiUrl}/post-todo`, { "PK": todoPost.id, "content": todoPost.content, "completed": !todoPost.completed }).subscribe(data => {
      console.log(data);
    })

    this.todos.map((v,i) => {
      if(i == id) v.completed = !v.completed

      return v;
    })
  }

  deleteTodo(id:number) {
    // need to call the db and mdelete the todo
    let todoDeleted = this.todos[id];
    this.todos = this.todos.filter((v,i) => i !== id);
    this.http.delete<any>(`${environment.apiUrl}/delete-todo?todo=${todoDeleted.id}`).subscribe(data => {
      console.log(data);
    })
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

      this.http.post<any>(`${environment.apiUrl}/post-todo`, { "PK": myId, "content":this.inputTodo, "completed": false }).subscribe(data => {
        console.log(data);
      })

      console.log(this.todos)
  
      this.inputTodo = "";
    }
  }

}
